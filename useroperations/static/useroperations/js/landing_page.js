const sliderElement = document.querySelector("#landing-page-slider-container");
sliderElement.addEventListener("mouseenter", () => stopCarousel());
sliderElement.addEventListener("mouseleave", () => startCarousel());

let carouselInterval;
startCarousel();

function carousel() {
  plusDivs(1);
}

function startCarousel() {
  carouselInterval = setInterval(carousel, 5000);
}

function stopCarousel() {
  clearInterval(carouselInterval);
}

var slideIndex = 1;
showDivs(slideIndex);

function plusDivs(n) {
  showDivs(slideIndex += n);
}

function currentDiv(n) {
  showDivs(slideIndex = n);
}

function showDivs(n) {
  var i;
  var x = document.getElementsByClassName("mySlides");
  var dots = document.getElementsByClassName("demo");
  if (n > x.length) {slideIndex = 1}
  if (n < 1) {slideIndex = x.length}
  for (i = 0; i < x.length; i++) {
    x[i].style.display = "none";  
  }
  for (i = 0; i < dots.length; i++) {
    dots[i].className = dots[i].className.replace(" w3-white", "");
  }
  x[slideIndex-1].style.display = "block";  
  dots[slideIndex-1].className += " w3-white";
}