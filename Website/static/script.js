const scooter = document.getElementById('scooter');
const pointers = document.querySelectorAll('.pointer');
let currentPointer = 0;

function moveScooter() {
    if (currentPointer < pointers.length) {
        const pointer = pointers[currentPointer];
        const rect = pointer.getBoundingClientRect();
        const mapRect = document.querySelector('.map-container').getBoundingClientRect();

        const scooterX = rect.left - mapRect.left + (rect.width / 2) - (scooter.offsetWidth / 2);
        const scooterY = rect.top - mapRect.top + (rect.height / 2) - (scooter.offsetHeight / 2);

        scooter.style.transform = `translate(${scooterX}px, ${scooterY}px)`;

        currentPointer++;
        setTimeout(moveScooter, 1000);
    }
}

// Start the animation
moveScooter();

/*const scooter = document.getElementById('scooter');

// Define the route as pairs of coordinates for map pointers
const route = [
    { top: '30%', left: '60%' },
    { top: '40%', left: '70%' },
    { top: '20%', left: '80%' },
    { top: '50%', left: '60%' },
];

let index = 0;

function moveScooter() {
    if (index < route.length) {
        scooter.style.top = route[index].top;
        scooter.style.left = route[index].left;
        index++;
        setTimeout(moveScooter, 2000); // Adjust speed of movement here
    }
}

// Start the animation after the page has loaded
window.onload = () => {
    moveScooter();
};*/