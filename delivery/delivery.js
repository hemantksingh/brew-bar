const faker = require("faker/locale/en_IND");
const AWS = require('aws-sdk');
AWS.config.update({region: process.env.AWS_REGION})
const eventBridge = new AWS.EventBridge();

// console.log(eventBridge);

function createDeliveryEvent(delivery) {
    return {
        Entries: [
            {
                Detail: JSON.stringify(delivery),
                DetailType: 'OrderDelivered',
                EventBusName: process.env.EVENT_BUS_NAME,
                Source: 'brewbar.delivery'
            }
        ]
    };
}

module.exports.handler = async (event) => {
    console.log('Event received: ', event);
    let deliveryEvent = createDeliveryEvent({
        orderId: event.detail.orderId,
        address : {
            line2: faker.address.streetName(),
            city: faker.address.city(),
            zipCode: faker.address.zipCode(),
            state: faker.address.state(),
            country: faker.address.country()
        }
    });

    console.log('Publishing order delivered event on ' + process.env.EVENT_BUS_NAME);
    const result = await eventBridge.putEvents(deliveryEvent).promise();
    console.log(result);

    return {
      statusCode: 202,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: "Order delivered",
        result: {}
      }),
    }
}