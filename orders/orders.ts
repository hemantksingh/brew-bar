import { Context, APIGatewayProxyCallback, APIGatewayEvent } from 'aws-lambda';
import AWS from 'aws-sdk';

export const lambdaHandler = (event: APIGatewayEvent, context: Context, callback: APIGatewayProxyCallback): void => {
    console.log("We are here!");
    console.log(`Event: ${JSON.stringify(event, null, 2)}`);
    console.log(`Context: ${JSON.stringify(context, null, 2)}`);

    // persist the order
    // const docClient = new AWS.DynamoDB.DocumentClient();

    // publish orderPlaced event
    // post event to internal api gw
    
    callback(null, {
        statusCode: 202,
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            message: "Event OrderPlaced published",
            result: {}
        }),
    });
};