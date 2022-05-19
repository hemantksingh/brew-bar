function startGame(name: string) {
    /* N/A outside a browser 
        var messages = document.getElementById('messages');
        messages!.innerText = 'Welcome to the multi math game';
    */
    let currentTime = new Date().toLocaleString('en-GB', {timeZone: 'UTC'});
    console.log(`New game starting for player '${name}' at ${currentTime}`);
}

startGame('foobar');