<template>
  <div id="app">
    <h1>Current Temperature</h1>
    <h2 v-if="currTemp">{{currTemp.temp}} F</h2>
    <h2>Recent Temps</h2>
    <ul>
      <li v-for="temp in temps" v-bind:key="temp.time"> {{temp.temp}} F at {{temp.time}} </li>
    </ul>
    <h2>Violations</h2>
    <ul>
      <li v-for="violation in violations" v-bind:key="violation.time"> {{violation.temp}} F at {{violation.time}} </li>
    </ul>
  </div>
</template>

<script>
import axios from 'axios';
export default {
  name: 'Temps',
  data() {
    return {
      message: 'vue is working!',
      temps: [],
      violations: [],
      currTemp: null,
      resp: [],
    }
  },
  methods: {
    getTemperatures: function() {
      const url = 'http://192.168.1.4:8080/sky/cloud/UJxF4DFPZQ9TTE5VmWypwr/temperature_store/temperatures'
      axios.get(url).then(resp => {
        this.temps = resp.data.reverse();
        if(this.temps.length > 0)
          this.currTemp = this.temps[0]
      })
    },
    getViolations: function() {
      const url = 'http://192.168.1.4:8080/sky/cloud/UJxF4DFPZQ9TTE5VmWypwr/temperature_store/threshold_violations'
      axios.get(url).then(resp => {
        this.violations = resp.data.reverse();
      })
    },
  },
  mounted: function() {
    window.console.log('created called');
    window.setInterval(() => {
      this.getTemperatures(),
      this.getViolations()
    }, 3000)
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
</style>
