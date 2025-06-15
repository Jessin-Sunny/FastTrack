document.addEventListener('DOMContentLoaded', () => {
    const scrollableElement = document.querySelector('.scrollable-element');

    // Scroll to a specific position
    scrollableElement.scroll({
        top: 100,
        behavior: 'smooth'
    });
});
document.getElementById("terms").addEventListener("change", function() {
    document.getElementById("register-btn").disabled = !this.checked;
});