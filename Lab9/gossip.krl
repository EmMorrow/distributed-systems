ruleset gossip {
  meta {
    shares getMessages, getPeer, getSeq, getUnseenMessages, prepareSeen,
      prepareRumor, prepareMessage, addMySeen, addPeerSeen, send, messageNotAlreadyReceived, __testing
    use module io.picolabs.subscription alias Subs
  }
  global {
    __testing = { "queries": [ { "name": "__testing" }, { "name": "getMessages"} ],
                  "events": [ { "domain": "gossip", "type": "seen",
                              "attrs": [ "message", "sender" ] } ,
                            { "domain": "wovyn", "type": "temp_added",
                              "attrs": [ "time", "temp" ] }
                              ] }

       // use Tx_role and Rx_role in each subscription to simply be "node".

    // use the current state to figure out which peer to send to
    // choose a peer that needs something from you
    // if last seen message indicates its seen everything then dont send to them
    getMessages = function() {
      ent:all_messages
    }

    getPeer = function() {
      subs = Subs:established("Rx_role","node").klog("all subs!: ");
      rand_sub = random:integer(subs.length() - 1);

      peers = ent:peer_seen;
      peers_in_need = peers.filter(function(v,k){
          getUnseenMessages(v).length() > 0;
      });

      rand = random:integer(peers_in_need.length() - 1);
      peer_to_send = peers_in_need.keys()[rand];

      sub = subs.filter(function(sub){
        add = (sub{"Rx"} == peer_to_send) => true | false;
        add;
      }).klog("(getPeer) sub: ");
      send = sub.length() == 0 => subs[rand_sub] | sub;
      send;
    }

    getPeerSeen = function() {
      ent:peer_seen
    }

    getSeq = function(messageID) {
      seq = messageID.split(":")[1].as("Number");
      seq;
    }

    // returns a list of messages a peer hasn't seen
    getUnseenMessages = function(seen) {
     unseen = ent:all_messages.filter(function(rumor) {
        rumor.klog("(getUnseenMessages) currRumor: ");
        curr_id = rumor{"SensorID"};
        seen.klog("(getUnseenMessages) seen: ");
        seen{curr_id}.klog("(getUnseenMessages) seen at curr_id: ");
        add = seen{curr_id}.isnull() || (seen{curr_id} < getSeq(rumor{"MessageID"})) => true | false;
        add
      });
      unseen.klog("(getUnseenMessages) unseen: ");
    }

    prepareSeen = function() {
      // make a map that maps pico id's to the max num of messages you've seen
      ent:seen.defaultsTo({}).klog("prepareSeen: ")
    }

    // look at peer seen to see what you should send, update peer_seen here as well
    prepareRumor = function(peer) {
      peer.klog("(prepareRumor) Peer options we have: ");
      peer_id = peer{"Rx"};
      peer_id.klog("(prepareRumor) peer_id: ");
      ent:peer_seen.klog("(prepareRumor) peer_seen: ");
      unseen = getUnseenMessages(ent:peer_seen.get(peer_id));
      rumor = unseen[0];

      // add to peer_seen
      addPeerSeen(peer_id, getSeq(rumor{"MessageID"}), rumor{"SensorID"});
      rumor
    }

    // return message, randomly choose a message type
    prepareMessage = function(peer) {
      type = random:integer(1);
      message = (type == 1) => prepareSeen() | prepareRumor(peer);
      obj = {"message": message, "type": type};
      obj
    }

    // update state of who has been sent what
    addMySeen = function(originId, seq) {
      max = ent:seen.get(originId).defaultsTo(0);
      new_max = (seq - max == 1) => seq | max;
      ent:seen.put(origin, new_max);
    }

    addPeerSeen = function(peerId, seq, sensorId) {
      // set the default if it has not been initialized
      peer_seen = getPeerSeen().get(peerId).defaultsTo({});
      old_seq = getPeerSeen().get([peerId, sensorId]).defaultsTo(0);

      new_seq = (seq - old_seq == 1) => seq | old_seq;
      getPeerSeen().klog("peer seen before adding peer seen: ");
      ent:peer_seen.klog("just peer seen before: ");
      getPeerSeen().put([peerId, sensorId], new_seq).klog("peer seen after: ");
    }

    // send the message to the peer
    send = function(message, peer, type) {
      event:send(
              { "eci": peer{"Tx"}, "eid": "gossip_message",
                  "domain": "gossip", "type": type,
                  "attrs": {"message": message, "sender": {"picoId": meta:picoId, "Rx": peer{"Rx"}, "Tx": peer{"Tx"}}}
              }
          )
    }

    messageNotAlreadyReceived = function(message) {
      meta:picoId.klog("(messageNotAlreadyReceived) curr pico: ");
      ent:all_messages.klog("(messageNotAlreadyReceived) all_messages: ");
      message.klog("(messageNotAlreadyReceived) message: ");
      match = ent:all_messages.filter(function(msg) {
        msg{"MessageID"} == message{"MessageID"}
      });
      match.klog("(messageNotAlreadyReceived) match: ");
      noexist = (match.length()) == 0 => true | false;
      noexist
    }
  }


  rule add_temp {
    select when wovyn temp_added
    pre {
      temp = event:attr("temp")
      time = event:attr("time")
      seq = ent:sequence.defaultsTo(1)

      sensorId = meta:picoId
      messageId = sensorId + ":" + seq

      message = {
        "SensorID": sensorId,
        "MessageID": messageId,
        "Time": time,
        "Temp": temp,
      }
    }

    always {
      ent:sequence := ent:sequence + 1;
      ent:all_messages := ent:all_messages.append(message);
      ent:seen.klog("(add_temp)seen before: ");
      ent:seen{sensorId} := seq;
      ent:seen.klog("(add_temp)seen after: ");
    }
  }

  // setup that responds to a startup event and
  // sets the schedule for the pico have this trigger
  rule initialization {
    select when wrangler ruleset_added
    always {
      ent:sequence := 1;
      ent:all_messages := [];
      ent:seen := {};
      ent:peer_seen := {};
      schedule gossip event "heartbeat" repeat "*/60  *  * * * *"
    }
  }

  // scheduled event in the pico will periodically send itself a gossip_heartbeat event
  // sends a message to one of the picos subs
  rule gossip_heartbeat {
    select when gossip heartbeat
    pre {
      subscriber = getPeer().klog("Subscriber: ")
      obj = prepareMessage(subscriber)
      m = obj{"message"}.klog("Message: ")
      type = (obj{"type"} == 1) => "seen" | "rumor"

      hi = subscriber{"Tx"}.klog("gossip heartbeat: subTx: ")
    }

    if not m.isnull() then
      event:send ({
        "eci": subscriber{"Tx"},
        "eid": "gossip_message",
        "domain": "gossip",
        "type": type,
        "attrs": {"message": m, "sender": {"picoId": meta:picoId, "Rx": subscriber{"Tx"}, "Tx": subscriber{"Rx"}}}
      });
  }

  rule respond_to_rumor {
    select when gossip rumor
    pre {
      msg = event:attr("message").klog("(respond_to_rumor) message: ")
      seq = getSeq(msg{"MessageID"})
      sensorId = msg{"SensorID"}
    }

    if messageNotAlreadyReceived(msg) then
      noop();

    fired {
      ent:all_messages.klog("(respond_to_rumor) all_messages before: ");
      ent:all_messages := ent:all_messages.append(msg);
      ent:all_messages.klog("(respond_to_rumor) all_messages after: ");

      max = ent:seen.get(sensorId).defaultsTo(0).klog("max: ");
      new_max = (seq - max == 1) => seq | max;
      ent:seen.klog("(respond_to_rumor) seen before: ");
      ent:seen := ent:seen.put(sensorId, new_max);
      ent:seen.klog("(respond_to_rumor) seen after: ");
    }
    // store rumor in ent var, if you havent seen that
    // high yet then make sure to not report it as the highest sequence
    // when sending a seen message
  }

  rule respond_to_seen {
    select when gossip seen

    pre {
      message = event:attr("message")
      sender = event:attr("sender").klog("This is the sender info: ")
      originId = message{"originId"}
      peerId = sender{"Rx"}.klog("THis is the peer Id we assign it to: ")
    }
    // update peer_seen

    always {
      ent:peer_seen := ent:peer_seen.put(peerId, message);
      raise gossip event "seen_resp" attributes {"sender": sender};
    }
    // check for any rumors not in the message and send them
    // as rumors back
  }

  rule send_unseen {
    select when gossip seen_resp
    foreach getUnseenMessages(event:attr("message")) setting (msg)
      pre {
        sender = event:attr("sender")
        peerId = sender{"Tx"}
      }
      event:send ({
        "eci": sender{"Rx"},
        "eid": "gossip_rep",
        "domain": "gossip",
        "type": "rumor",
        "attrs": {"message": msg, "sender": {"picoId": meta:picoId, "Rx": sender{"Tx"}, "Tx": sender{"Rx"}}}
      })
  }
}
