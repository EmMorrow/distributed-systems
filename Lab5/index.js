import Vue from 'vue'
import axios from 'axios'

app = new Vue({
  el: '#app',
  data: {
    message: 'vue is working!',
    temps: [],
    violations: [],
    currTemp: '60 F'
  },
  methods: {
    getTemperatures: function() {
      console.log('getTemps calleds')
      axios
        .get('http://192.168.1.4:8080/sky/cloud/UJxF4DFPZQ9TTE5VmWypwr/temperature_store/temperatures')
        .then(response => (this.temps = resonse))
    },
    getViolations: function() {

    }
  },
  mounted: function() {
    console.log('created called');
    window.setInterval(() => {
      this.getTemperatures()
    }, 3000)
  }
})
