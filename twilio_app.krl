ruleset twilio_app {
  meta {
    use module twilio_keys
    use module twilio_db alias twilio
      with account_sid = keys:twilio{"account_sid"}
           auth_token = keys:twilio{"auth_token"}
  }

  rule send_sms {
    select when test new_message
    twilio:send_sms(event:attr("to"),
             event:attr("from"),
             event:attr("message"))
  }

  rule messages {
    select when test messages
    twilio:messages(event:attr("to"),
             event:attr("from"))
  }
}
