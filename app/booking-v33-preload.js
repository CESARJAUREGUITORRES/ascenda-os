'use strict'
const http=require('http')
const {createBookingPublicV33}=require('./booking-public-v33')
const original=http.createServer
if(!http.createServer.__bookingV33){
  http.createServer=function(listener){
    const booking=createBookingPublicV33({supabaseUrl:process.env.SUPABASE_URL,serviceRoleKey:process.env.SUPABASE_SERVICE_ROLE_KEY,resendApiKey:process.env.RESEND_API_KEY})
    return original.call(http,function(req,res){let p='/';try{p=new URL(req.url,'http://localhost').pathname}catch(_){}if(p==='/api/booking/public-confirmation-v33')return booking(req,res);return listener(req,res)})
  }
  http.createServer.__bookingV33=true
}
