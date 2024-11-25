// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Scale the background to the document width
window.scaleBackground = function(){
  document.querySelectorAll('header, article').forEach(function(element){
    element.style.backgroundPosition = `-${element.offsetLeft}px -${element.offsetTop}px`
    element.style.backgroundSize = `${document.body.clientWidth}px`
  });
}

document.addEventListener('DOMContentLoaded', function(){
  scaleBackground();
});

window.addEventListener('resize', function(){
  scaleBackground();
});
