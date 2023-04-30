// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {
    ShowError: {
        mounted() {
            this.el.classList.add('opacity-0', 'translate-y-full', 'fixed', 'top-0', 'left-0', 'w-full');
        
            setTimeout(() => {
              this.el.classList.remove('opacity-0');
              this.el.classList.add('transition', 'duration-300', 'ease-out', 'opacity-100', 'translate-y-0');
            }, 100);
        
            setTimeout(() => {
              this.el.classList.remove('opacity-100');
              this.el.classList.add('opacity-0', 'translate-y-full');
            }, 3000);
          }
    }
}


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())


window.addEventListener(`phx:js-exec`, (e) => {
    el = document.querySelector(e.detail.to)
    liveSocket.execJS(el, el.getAttribute(e.detail.attr))
})



// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

