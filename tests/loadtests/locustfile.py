import json
import os
import uuid
from locust import HttpUser, task, between
from faker import Faker
from config import Config
from env import Env

# An instance of this class is created for every user that locust simulates,
# and each of these users will start running within their own green gevent thread


class OrdersUser(HttpUser):
    host = Config().get_uri(Env().get_env_var('ORDERS_API_ID'), 'brewbar')

    # make the simulated users wait (sleep) between 2 and 5 seconds after each task has finished executing
    wait_time = between(2, 5)

    # for every running user, locust creates a greenlet (micro-thread), that will call methods
    # decorated with @task
    @task
    def orders(self):
        fake = Faker('en_GB')
        order = {
            "firstName": fake.first_name(),
            "lastName": fake.last_name(),
            "phoneNumber": fake.phone_number(),
            "address": {
                "line1": fake.building_number(),
                "line2": fake.street_name(),
                "city": fake.city(),
                "postcode": fake.postcode(),
                "state": fake.city_suffix(),
                "country": fake.country()
            }
        }
        # client is an instance of HttpSession provided by inheriting from HttpUser
        self.client.post("/orders", json=order)


# class DeliveryUser(HttpUser):
#     host = Config().get_uri(Env.get_env_var('EVENTS_API_ID'), 'events')
#     wait_time = between(2, 5)

#     @task
#     def deliveries(self):
#         fake = Faker()
#         ordersDelivered = {
#             "ordersDelivered": [
#                 {
#                     "orderId": str(uuid.uuid4()),
#                     "address": {
#                         "line2": fake.street_address(),
#                         "city": fake.city(),
#                         "zipCode": fake.postcode(),
#                         "state": fake.city_suffix(),
#                         "country": fake.country()
#                     }
#                 }
#             ]
#         }
#         print(f"Sending request to '{self.host}' with payload: {json.dumps(ordersDelivered)}")
#         self.client.post("/delivery", json=ordersDelivered)
