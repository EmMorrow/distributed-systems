ruleset temperature_store {
  meta {
    shares __testing, temperatures, threshold_violations, inrange_temperatures
    provides temperatures, threshold_violations, inrange_temperatures
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "wovyn", "type": "threshold_violation",
                              "attrs": [ "temp", "timestamp" ] } ] }
    temperatures = function() {
      ent:temps
    }

    threshold_violations = function() {
      ent:violations
    }

    inrange_temperatures = function() {
      ent:temps.difference(ent:violations)
    }
  }

  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature").klog("find high temps, temp ")
      time = event:attr("timestamp")
    }

    always {
      ent:temps := (ent:temps.isnull() => [] | ent:temps)
      ent:temps := ent:temps.append({"temp":temp, "time":time})
    }
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre {
      temp = event:attr("temperature")
      time = event:attr("timestamp")
    }

    always {
      ent:violations := (ent:violations.isnull() => [] | ent:violations)
      ent:violations := ent:violations.append({"temp":temp, "time":time})
    }
  }

  rule clear_temperatures {
    select when sensor reading_reset
    always {
      ent:violations := []
      ent:temps := []
    }
  }
}
