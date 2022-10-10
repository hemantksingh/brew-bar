import { Context, APIGatewayProxyCallback, APIGatewayEvent, EventBridgeEvent } from 'aws-lambda';
import AWS from 'aws-sdk';
import axios from 'axios';


type OrderDeliveredEvent = {
    orderId: string;
    firstName: string;
    lastName: string;
    phoneNumber: string;
    dispatchedOn: string;
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

export const lambdaHandler = (event: EventBridgeEvent<any, any>, context: Context, callback: APIGatewayProxyCallback): void => {
    console.log(`Event: ${JSON.stringify(event, null, 2)}`);
    console.log(`Context: ${JSON.stringify(context, null, 2)}`);


    // deduplicate and persist the order
    // const docClient = new AWS.DynamoDB.DocumentClient();

    if (event?.detail == null)
        throw new Error("Event detail cannot be null");

    const now = new Date();
    // publish orderDelivered event
    publishEvent({
        orderId: event.detail.orderId,
        firstName: event.detail.firstName,
        lastName: event.detail.lastName,
        phoneNumber: event.detail.phoneNumber,
        dispatchedOn: now.toUTCString(),
        address: event.detail.address
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


async function publishEvent(event: OrderDeliveredEvent) {
    try {
        const orderDeliveredUri = `${process.env.INTERNAL_EVENTS_API_URI}/order-delivered`;
        console.log(`Sending event ${JSON.stringify(event)} to ${orderDeliveredUri}`);
        await axios.post(orderDeliveredUri, event, {
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