const delivery = require ('./delivery.js');
const dotenv = require('dotenv');
dotenv.config();

const main = async () => {
    await delivery.handler({
        detail : {
            orderId: 1
        }
    });
}

main();


