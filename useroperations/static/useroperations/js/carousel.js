var carousel_initial_stop = true;
carousel();

function carousel() {
  if (carousel_initial_stop) {
    carousel_initial_stop = false;
    setTimeout(carousel, 5000);
  } else {
    plusDivs(1)
    setTimeout(carousel, 5000);
  }
}