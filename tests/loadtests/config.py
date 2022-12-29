class Config():
    
    region = 'eu-west-2'

    def get_uri(self, api_id, stage):
        return f"https://{api_id}.execute-api.{self.region}.amazonaws.com/{stage}"