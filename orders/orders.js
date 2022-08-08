const AWS = require('aws-sdk');
AWS.config.update({region: process.env.AWS_REGION})
const eventBridge = new AWS.EventBridge();

console.log(eventBridge);

const params = {
    Entries: [
        {
            Detail: JSON.stringify({
                "message" : "Order placed"
            }),
            DetailType: 'message',
            EventBusName: 'hk-playground-more-sole',
            Source: 'brewbar.orders'
        }
    ]
}

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
    const result = await eventBridge.putEvents(params).promise()
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

// const main = async () => {
//     await this.handler({});
// }

// main();