const carousel_timeout = 5000;
const sliderElement = document.querySelector("#landing-page-slider-container");
sliderElement.addEventListener("mouseenter", mouseOver);
sliderElement.addEventListener("mouseleave", mouseOut);

let carousel_initial_stop = true;
let carousel_mouseOver_stop = false;
carousel();

function carousel() {
  if (carousel_initial_stop) {
    carousel_initial_stop = false;
    setTimeout(carousel, carousel_timeout);
  } else if(!carousel_mouseOver_stop) {
    plusDivs(1)
    setTimeout(carousel, carousel_timeout);
  }
}

function mouseOver() {
  carousel_mouseOver_stop = true;
}

function mouseOut() {
  carousel_mouseOver_stop = false;
  setTimeout(carousel, carousel_timeout);
}