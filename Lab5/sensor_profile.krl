ruleset sensor_profile {
  meta {
    provides get_user_profile
    shares get_user_profile
  }
  global {
    get_user_profile = function() {
      {
        "name": ent:name,
        "location": ent:location,
        "threshold": ent:threshold,
        "to": ent:to,
      }
    }
  }

  rule update_profile {
    select when sensor profile_updated
    pre {
      name = event:attr("name")
      location = event:attr("location")
      threshold = event:attr("threshold").defaultsTo(ent:threshold)
      number = event:attr("to").defaultsTo(ent:to)

      threshold = threshold.isnull() => 75 | threshold
      number = number.isnull() => "+16512300419" | number
    }

    always {
      ent:name := name;
      ent:location := location;
      ent:threshold := threshold;
      ent:to := number;
    }
  }
}
