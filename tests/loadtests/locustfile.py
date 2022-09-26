import json
import os
from locust import HttpUser, task, between
from config  import Config

# An instance of this class is created for every user that locust simulates, 
# and each of these users will start running within their own green gevent thread
class OrdersUser(HttpUser):
    
    host = Config().get_uri('i4uohrymbf', 'brewbar')

    # make the simulated users wait (sleep) between 2 and 5 seconds after each task 
    # has finished executing
    wait_time = between(2, 5)

    # For every running user, locust creates a greenlet (micro-thread), that will call methods
    # decorated with @task
    @task
    def orders(self):
        self.client.get("/orders")

class DeliveryUser(HttpUser):
    host = Config().get_uri('7k6syyy2f4', 'dev')
    wait_time = between(2, 5)

    @task
    def deliveries(self):
        # client is an instance of HttpSession provided by inheriting from HttpUser
        self.client.post("/delivery", json={
            "ordersDelivered": [
                {
                    "orderId": "a0874e2c-4ad3-4fda-8145-18cc51616ecd",
                    "address": {
                        "line2": "10 Broad Road",
                        "city": "Altrincham",
                        "zipCode": "WA15 7PC",
                        "state": "Cheshire",
                        "country": "United Kingdom"
                    }
                }
            ]
        })