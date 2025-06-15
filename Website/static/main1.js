document.querySelector('form').addEventListener('submit', (event) => {
    event.preventDefault(); // Prevent form submission

    const selectedEmployees = [];
    document.querySelectorAll('input[type="checkbox"]:checked').forEach(checkbox => {
        const employeeItem = checkbox.closest('.employee-item');
        selectedEmployees.push({
            id: employeeItem.querySelector('.emp-id').textContent,
            name: employeeItem.querySelector('.emp-name').textContent
        });
    });

    // Store selected employees in localStorage
    localStorage.setItem('selectedEmployees', JSON.stringify(selectedEmployees));

    // Redirect to the selected employees page
    window.location.href = 'selected.html';
});