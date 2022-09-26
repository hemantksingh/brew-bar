class Config():
    
    region = 'eu-west-1'

    def get_uri(self, api_id, stage):
        return f"https://{api_id}.execute-api.{self.region}.amazonaws.com/{stage}"