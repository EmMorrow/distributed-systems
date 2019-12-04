<template>
  <div id="app">
    <h1>User Profile</h1>
    <p>
      <label for="name">Name </label>
      <input
        id="name"
        v-model="name"
        type="text"
        name="name"
      >
    </p>

    <p>
      <label for="location">Location </label>
      <input
        id="location"
        v-model="location"
        type="text"
        name="location"
      >
    </p>
    <p>
      <label for="threshold">Threshold </label>
      <input
        id="threshold"
        v-model="threshold"
        type="number"
        name="threshold"
      >
    </p>
    <p>
      <label for="to">To Phone Number </label>
      <input
        id="to"
        v-model="to"
        type="text"
        name="to"
      >
    </p>
    <p>
      <button v-on:click="checkForm">Submit</button>
    </p>

  </div>
</template>

<script>
import axios from 'axios';
export default {
  name: 'Profile',
  data() {
    return {
      name: null,
      location: null,
      threshold: null,
      to: null,
    }
  },
  methods: {
    checkForm: function() {
      const url = 'http://192.168.1.4:8080/sky/event/UJxF4DFPZQ9TTE5VmWypwr/0/sensor/profile_updated'
      // include params that you get from the form
      window.console.log("name")
      window.console.log(this.name)
      var params = {
        "name": this.name,
        "location": this.location,
        "threshold": this.threshold,
        "to": this.to,
      }
      window.console.log(params)
      axios.post(url, params).then(resp => {
        window.console.log(resp)
      })
    },
    getProfile: function() {
      window.console.log("getProfile")
      const url = 'http://192.168.1.4:8080/sky/cloud/UJxF4DFPZQ9TTE5VmWypwr/sensor_profile/get_user_profile'
      axios.get(url).then(resp => {
        window.console.log(resp)
        this.name = resp.data.name
        this.location = resp.data.location
        this.threshold = resp.data.threshold
        this.to = resp.data.to
      })
    }
  },
  mounted: function() {
    this.getProfile()
  }
}
</script>

<style>
#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}

.row {
  display: inline-block;
}
</style>
