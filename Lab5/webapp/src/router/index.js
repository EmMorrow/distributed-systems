import Vue from 'vue'
import VueRouter from 'vue-router'
import Temps from '../components/Temps.vue'
import Profile from '../components/Profile.vue'

Vue.use(VueRouter)

const routes = [
  {
    path: '/',
    name: 'temps',
    component: Temps
  },
  {
    path: '/profile',
    name: 'profile',
    // route level code-splitting
    // this generates a separate chunk (about.[hash].js) for this route
    // which is lazy-loaded when the route is visited.
    component: Profile
  }
]

const router = new VueRouter({
  routes
})

export default router
