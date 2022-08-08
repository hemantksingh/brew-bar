module.exports.handler = async (event) => {
    console.log('Event received: ', event);
    
    return {
      statusCode: 202,
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: "Delivery done",
        result: {}
      }),
    }
}