const container = document.querySelector('.container');
const registerBtn = document.querySelector('.register-btn');
const loginBtn = document.querySelector('.login-btn');

// Event listener for the Register button
registerBtn.addEventListener('click', () => {
    container.classList.add('active');
});

// Event listener for the Login button
loginBtn.addEventListener('click', () => {
    container.classList.remove('active');
});
