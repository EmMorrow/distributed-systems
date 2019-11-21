ruleset wovyn_base {
  meta {
    shares __testing
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "wovyn", "type": "heeartbeat",
                              "attrs": [ "temp", "baro" ] } ] }
    temperature_threshold = 76

  }

  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      info = event:attr("genericThing")
      temp = event:attr("genericThing"){"data"}{"temperature"}[0]{"temperatureF"}
    }

    if not info.isnull() then
      send_directive("say", {
        "message": "Hello World",
        "temp": temp
      })
    fired {
      raise wovyn event "new_temperature_reading"
        attributes {"temperature": temp, "timestamp": time:now()}
    }
  }

  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature")
    }
    if temp > temperature_threshold then
      send_directive("violation")
    fired {
      raise wovyn event "threshold_violation"
        attributes {"temperature": temp, "timestamp": time.now()}
    }
  }

  
}
