import json
import os
import uuid
from locust import HttpUser, task, between
from faker import Faker
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
        fake = Faker()
        ordersDelivered = {
            "ordersDelivered" : [
                {
                    "orderId" : str(uuid.uuid4()),
                    "address" : {
                        "line2" : fake.street_address(),
                        "city" : fake.city(),
                        "zipCode" : fake.postcode(),
                        "state" : fake.city_suffix(),
                        "country" : fake.country()
                    }
                }
            ]
        }
        print(json.dumps(ordersDelivered))
        # client is an instance of HttpSession provided by inheriting from HttpUser
        self.client.post("/delivery", json= ordersDelivered)