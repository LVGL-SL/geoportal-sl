const sliderElement = document.querySelector("#landing-page-slider-container");
sliderElement.addEventListener("mouseenter", () => stopCarousel());
sliderElement.addEventListener("mouseleave", () => startCarousel());

let carouselInterval;
startCarousel();

function carousel() {
  plusDivs(1);
  setTimeout(carousel, carousel_timeout);
}

function startCarousel() {
  carouselInterval = setInterval(carousel, 5000);
}

function stopCarousel() {
  clearInterval(carouselInterval);
}