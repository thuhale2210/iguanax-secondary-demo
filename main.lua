local ROUTING_TABLE = {
   MAIN_HOSPITAL = "PROD",
   LAB           = "PROD",
   RADIOLOGY     = "PROD",
   PHARMACY      = "PROD",
   EMERGENCY     = "PROD",
   CLINIC        = "PROD",
   ICU           = "PROD",
   SURGERY       = "PROD",

   TEST_CLINIC   = "NONPROD",
   DEV_SYSTEM    = "NONPROD",
   UAT_ENV       = "NONPROD",
   TRAINING_LAB  = "NONPROD",
   SANDBOX       = "NONPROD"
}

function RouteFacility(Facility)
   local f = string.upper(Facility or "")
   return ROUTING_TABLE[f] or "NONPROD"
end

function PIImask(msg)
   if not msg.PID then
      return msg
   end
   
   -- Mask patient name
   if msg.PID[5] and msg.PID[5][1] then
      if msg.PID[5][1][1] then
         msg.PID[5][1][1][1] = 'XXXX' -- Family name
      end
      if msg.PID[5][1][2] then
         msg.PID[5][1][2] = 'XXXX' -- Given name          
      end
   end
      
   -- Mask DOB
   if msg.PID[7] then
      msg.PID[7] = 'XXXXXXXX'
   end
            
   -- Mask SIN
   if msg.PID[19] then
      msg.PID[19] = 'XXX-XXX-XXX'
   end
      
   -- Mask phone number
   if msg.PID[13] and msg.PID[13][1] then
      msg.PID[13][1][1] = 'XXX-XXX-XXXX'
   end
      
   -- Mask address
   if msg.PID[11] and msg.PID[11][1] and msg.PID[11][1][1] then
      msg.PID[11][1][1][1] = '123'
      msg.PID[11][1][1][2] = 'MASKED STREET'
   end
      
   if msg.PID[11] and msg.PID[11][1] then
      msg.PID[11][1][3] = 'MASKED CITY'
      msg.PID[11][1][4] = 'MASKED STATE'
      msg.PID[11][1][5] = 'XXXXX'
   end
      
   return msg
end

function main(Data)
   local msg = hl7.parse{vmd='simple.vmd', data=Data}
   local facility = tostring(msg.MSH[4][1] or "")
   local route = RouteFacility(facility)

   -- Resolve component IDs
   local comps = iguana.components()
   local prodId    = comps["Test Listener (Prod)"]
   local nonProdId = comps["Test Listener (Nonprod)"]

   if not prodId or not nonProdId then
      error("HL7 Router cannot find listener components. Check names.")
   end

   local out = Data

   if route == "NONPROD" and Data:find("PID|", 1, true) then
      msg = PIImask(msg)
      out = msg:S()
      iguana.logInfo("ROUTER: NONPROD masking applied")
   end

   iguana.logInfo("ROUTER: FACILITY="..facility.." ROUTE="..route)

   -- Targeted send
   if route == "PROD" then
      message.send{data=out, id=prodId}
   else
      message.send{data=out, id=nonProdId}
   end
end