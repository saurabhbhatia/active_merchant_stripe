module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class StripeGateway < Gateway
      TEST_URL = 'https://api.stripe.com/v1'
      LIVE_URL = 'https://api.stripe.com/v1'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover,:jcb]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.stripe.com/'
      
      # The name of the gateway
      self.display_name = 'Stripe'

#parse the response of the api 
class Response
    def initialize(hash)
      @data = hash
    end

    InspectKey = :__inspect_key__
    def inspect
      str = "#<#{self.class}"

      Thread.current[InspectKey] ||= []
      if Thread.current[InspectKey].include?(self) then
        str << " ..."
      else
        first = true
        for k,v in @data
          str << "," unless first
          first = false
#separate the attribute id required for identification of transaction through stripe gateway
          Thread.current[InspectKey] << v
          begin
            str << " #{k}=#{v.inspect}"
          ensure
            Thread.current[InspectKey].pop
          end
        end
      end

      str << ">"
    end

    def method_missing(name, *args)
      @data[name.to_s]
    end
    
    def id
      @data['id']
    end
  end

    

#initialize the api key of stripe
  def initialize(key)
     @key = key
  end

#retrieve a charge transaction according to the id 
def retrieve(opts)
      requires!(opts, :id)
      
      r = req({
        :id => opts[:id],
        :method => 'retrieve_charge'
      })

      Response.new(r)
    end


def requires!(hash, *params)
      params.each do |param| 
        if param.is_a?(Array)
          raise ArgumentError.new("Missing required parameter: #{param.first}") unless hash.has_key?(param.first) 

          valid_options = param[1..-1]
          raise ArgumentError.new("Parameter: #{param.first} must be one of #{valid_options.to_sentence(:words_connector => 'or')}") unless valid_options.include?(hash[param.first])
        else
          raise ArgumentError.new("Missing required parameter: #{param}") unless hash.has_key?(param) 
        end
      end
    end

#charge a credit card 
    def execute(opts)
      requires!(opts, :amount, :currency)
      
      unless opts[:card] or opts[:customer]
        raise ArgumentError.new("Missing parameters: execute() requires either :card (card hashmap) or :customer (customer id).")
      end
      
      opts.merge!({
        # will override opts
        :method => 'execute_charge'
      })
      
      r = req(opts)
      Response.new(r)
    end

#refund an amount to the credit card
 def refund(opts)
      requires!(opts, :id)
      
      opts.merge!({
        :method => 'refund_charge'
      })
      
      r = req(opts)
      Response.new(r)
    end

#generate a new customer id  - recurring billing method 
    def create_customer(opts)
      r = req(opts.merge!(:method => 'create_customer'))
      Response.new(r)
    end

#update a customer's detail    - recurring billing method
    def update_customer(opts)
      requires!(opts, :id)
      r = req(opts.merge(:method => 'update_customer'))
      Response.new(r)
    end
    
#bill a customer on a periodical basis - recurring billing method
    def bill_customer(opts)
      requires!(opts, :id, :amount)
      r = req(opts.merge(:method => 'bill_customer'))
      Response.new(r)
    end
    
# retrieve customer details - recurring billing method
    def retrieve_customer(opts)
      requires!(opts, :id)
      r = req(opts.merge(:method => 'retrieve_customer'))
      Response.new(r)
    end

#delete customer from the database - recurring billing method
    def delete_customer(opts)
      requires!(opts, :id)
      r = req(opts.merge(:method => 'delete_customer'))      
    end

private

    #parameters to be sent along with api call
    def req(params)
      params = params.merge({
        :key => @key,
        :client => {
          :type => 'binding',
          :language => 'ruby',
          :version => @version
        }
      })
      puts params
#intialize client
      d = RestClient.post(LIVE_URL, params)
#store the api response hash in a variable
      resp = JSON.load(d.body)
      
#api error response 
   if resp['error']
        case resp['error']['type']
        when 'card_error'
          c = CardError.new(resp['error']['message'])
          c.param = resp['error']['param']
          c.code = resp['error']['code']
          raise c
        when 'invalid_request_error'
          i = InvalidRequestError.new(resp['error']['message'])
          i.param = resp['error']['param']
          raise i
        when 'api_error'
          raise APIError.new(resp['error']['message'])
        else
          raise resp['error']['message']
        end
      end

      resp
    end

#error difinitions
class Error < StandardError; end
  
  class CardError < StripeGateway::Error
    attr_accessor :param, :code
  end
  
  class InvalidRequestError < StripeGateway::Error;
    attr_accessor :param
  end
    
  class APIError < StripeGateway::Error; end
    
      end
 

    end
  end


