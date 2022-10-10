import { Context, APIGatewayProxyCallback, APIGatewayEvent } from 'aws-lambda';
import AWS from 'aws-sdk';
import axios from 'axios';
import { v4 as uuidv4 } from 'uuid';

type OrderPlacedEvent = {
    orderId: string;
    firstName: string;
    lastName: string;
    phoneNumber: string;
    address: Address;
}

type Address = {
    line1: string;
    line2: string;
    city: string;
    postcode: string;
    state: string;
    country: string;
}

export const lambdaHandler = (event: APIGatewayEvent, context: Context, callback: APIGatewayProxyCallback): void => {
    console.log(`Event: ${JSON.stringify(event, null, 2)}`);
    console.log(`Context: ${JSON.stringify(context, null, 2)}`);


    // deduplicate and persist the order
    // const docClient = new AWS.DynamoDB.DocumentClient();

    if (event?.body == null)
        throw new Error("Event body cannot be null");

    // publish orderPlaced event
    let order = JSON.parse(event.body);
    publishEvent({
        orderId: uuidv4(),
        firstName: order.firstName,
        lastName: order.lastName,
        phoneNumber: order.phoneNumber,
        address: order.address
    });

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


async function publishEvent(event: OrderPlacedEvent) {
    try {
        const orderPlacedUri = `${process.env.INTERNAL_EVENTS_API_URI}/order-placed`;
        console.log(`Sending event ${JSON.stringify(event)} to ${orderPlacedUri}`);
        await axios.post(orderPlacedUri, event, {
            headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
            },
        });
    } catch (error) {
        if (axios.isAxiosError(error)) {
            console.log('error message: ', error.message);
            // 👇️ error: AxiosError<any, any>
            return error.message;
        } else {
            console.log('unexpected error: ', error);
            return 'An unexpected error occurred';
        }
    }
}