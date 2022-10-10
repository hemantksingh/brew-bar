import os
import sys


class Env():

    def get_env_var(self, key):
        try:  
            return os.environ[key]
        except KeyError: 
            print(f"Please set the environment variable {key}")
            sys.exit(1)