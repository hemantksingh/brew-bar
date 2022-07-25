module.exports.handler = async (event) => {
    console.log('Event: ', event);
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