ruleset sensor_profile {
  meta {
    provides get_user_profile
    shares get_user_profile
  }
  global {
    get_user_profile = function() {
      {
        ent:name
        ent:location
        ent:temp
        ent:threshold
      }
    }
  }

  rule update_profile {
    select when sensor profile_updated
    pre {
      name = event:attr("name")
      location = event:attr("location")
      threshold = event:attr("threshold")
      number = event:attr("to")
    }

    always {
      ent:threshold := (ent:threshold.isnull()) => 75 | ent:threshold
      ent:to := (ent:to.isnull()) => '+16512300419' | ent:to

      ent:name := name
      ent:location := location
      ent:threshold := (threshold.isnull()) => ent:threshold | threshold
      ent:to := (number.isnull()) => ent:to | number
    }
  }
}
