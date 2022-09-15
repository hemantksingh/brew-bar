const faker = require("faker/locale/en_IND");
const AWS = require('aws-sdk');
AWS.config.update({region: process.env.AWS_REGION})
const eventBridge = new AWS.EventBridge();

// eventBridge.putEvents(params, (err, data) => {
//     if(data) {
//         console.log('Event sent ' + JSON.stringify(data.Entries));
//     } else {
//         console.log('Failed ' + JSON.stringify(err));
//     }
// });

// module.exports.eventHandler = async (event) => {
//     const result = await eventBridge.putEvents(params).promise()
//     console.log(result);
// }

function createOrderPlacedEvent (order) {
  return {
    Entries: [
        {
            Detail: JSON.stringify(order),
            DetailType: 'OrderPlaced',
            EventBusName: process.env.EVENT_BUS_NAME,
            Source: 'brewbar.orders'
        }
    ]
  };
}

function httpHandler(event) {
  let responseMessage = 'Orders Placed!';

    if (event.queryStringParameters && event.queryStringParameters['Name']) {
        responseMessage = 'Orders Placed for ' + event.queryStringParameters['Name'] + '!';
    }
  
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: responseMessage,
      }),
    }
}

module.exports.handler = async (event) => {
    console.log('Event received: ', event);
    let orderPlacedEvent = createOrderPlacedEvent({
      orderId: faker.datatype.uuid(),
      firstName: faker.name.firstName(),
      lastName: faker.name.lastName(),
      phoneNumber: faker.phone.phoneNumber(),
      vehicle: faker.vehicle.vehicle()
    });
    console.log('Publishing order placed event on event bus: ' + process.env.EVENT_BUS_NAME);
    const result = await eventBridge.putEvents(orderPlacedEvent).promise();
    console.log(result);

    return {
      statusCode: 202,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: "Event OrderPlaced published",
        result: result
      }),
    }
}