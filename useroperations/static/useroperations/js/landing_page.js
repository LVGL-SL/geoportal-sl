/* 
  carousel variables and configurations
*/
const CAROUSEL_INTERVAL_TIMEOUT_IN_MS = 5000;
var carouselIndex = 0;
let carouselInterval;
initiateCarousel();

/* 
  carousel functions
*/

function initiateCarousel() {

  const carouselContainer = document.querySelector('#landing-page-carousel-container');
  const carouselLeftButton = document.querySelector('#btn-carousel-left');
  const carouselRightButton = document.querySelector('#btn-carousel-right');
  const carouselCircleButtons = document.querySelectorAll('.carousel-dot');

  carouselContainer.addEventListener('mouseenter', () => stopCarousel());
  carouselContainer.addEventListener('mouseleave', () => startCarousel());
  carouselLeftButton.addEventListener('click', () => displayPreviousCarouselElement());
  carouselRightButton.addEventListener('click', () => displayNextCarouselElement());

  for (btn of carouselCircleButtons) {
    btn.addEventListener('click', (e) => {
      const newIndex = parseInt(e.target.dataset.index)
      displayCarouselElementByIndex(newIndex);
    });
  }

  displayCarouselElementByIndex(0);
  startCarousel();
}

function displayNextCarouselElement() {

  const newIndex = parseInt(carouselIndex + 1);
  displayCarouselElementByIndex(newIndex);
}

function displayPreviousCarouselElement() {

  const newIndex = parseInt(carouselIndex - 1);
  displayCarouselElementByIndex(newIndex);
}

function displayCarouselElementByIndex(index) {

  const carouselImages = document.querySelectorAll('.carousel-image');
  const carouselDots = document.querySelectorAll('.carousel-dot');

  if (index >= carouselImages.length) {
    carouselIndex = 0;
  } else if (index < 0) {
    carouselIndex = carouselImages.length - 1;
  } else {
    carouselIndex = index;
  }
  const currentImage = carouselImages[carouselIndex];
  const currentDot = carouselDots[carouselIndex];

  hideAllElements(carouselImages);
  for (dot of carouselDots) {
    dot.classList.remove("w3-white");
  }

  displayElementAsBlock(currentImage);
  currentDot.classList.add("w3-white");
}

function startCarousel() {
  carouselInterval = setInterval(displayNextCarouselElement, CAROUSEL_INTERVAL_TIMEOUT_IN_MS);
}

function stopCarousel() {
  clearInterval(carouselInterval);
}

/*
  Generic functions
*/

function hideAllElements(elements) {

  for (element of elements) {
    element.classList.remove("block");
    element.classList.add("hidden");
  }
}

function displayElementAsBlock(element) {

  element.classList.remove("hidden");
  element.classList.add("block");
}