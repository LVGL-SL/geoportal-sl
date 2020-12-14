// Using a Timeout as the DOM won't successfully load for some reason.
// TODO 
// 1. Fix DOM Loading (whereever the behaviour is caused)
// 2. Remove this setTimeout call
setTimeout(initialize_collapse_capability, 500);


function toggle_table_collapse(table_element) {

    const headline = table_element.querySelector('.mw-headline');

    if (table_element.classList.contains('mw-collapsed')) {
        headline.innerHTML = `&nbsp;<i class="fas fa-chevron-down"></i> ${headline.id}`;
        explode_table(table_element);
    } else {
        headline.innerHTML = `&nbsp;<i class="fas fa-chevron-right"></i> ${headline.id}`;
        collapse_table(table_element);
    }
}


function collapse_table(table) {

    const rows = table.querySelectorAll('tr');

    let header = true;
    for (row of rows) {
        if (!header) {
            row.setAttribute('style', 'display: none;');
        } else {
            header = false;
        }
    }
    table.classList.toggle('mw-collapsed');
}


function explode_table(table) {

    const rows = table.querySelectorAll('tr');

    let header = true;
    for (row of rows) {
        if (!header) {
            row.removeAttribute('style');
        } else {
            header = false;
        }
    }
    table.classList.toggle('mw-collapsed');
}


function add_eventlistener_to_table(table) {

    const table_heading = table.querySelector('th');

    table_heading.addEventListener('click', (event) => {
        const target_table = event.currentTarget.parentNode.parentNode.parentNode;
        toggle_table_collapse(target_table);
    });
}


function initialize_collapse_capability() {

    const collapsible_tables = document.querySelectorAll('.mw-collapsible');

    for (table of collapsible_tables) {
        table.classList.remove('mw-collapsed');
        add_eventlistener_to_table(table);
        toggle_table_collapse(table);
    }
}