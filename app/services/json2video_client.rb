require 'httparty'

class Json2videoClient

  MOVIES_ENDPOINT = "https://api.json2video.com/v2/movies"

  def self.create_scene_video(scene)
    payload           = {}
    story             = scene.story
    story_type        = story.story_type
  
    payload["id"]     = "story-#{scene.story_id}-scene-#{scene.id}"
    payload["fps"]    = 25
    payload["cache"]  = payload["draft"] = false
    payload["width"]  = story_type.output_width
    payload["height"] = story_type.output_height
    payload["scenes"] = create_scene_payload(scene, story_type)

    response = create_video(payload)
    puts response

    # {
    #   id: "id of all scenes combined?"
    #   fps:
    #   cache: false
    #   draft: false
    #   width
    #   height:
    #   scenes: [{ "elements": [
    #     { type: "",
    #       src: "" }
    #   ]
    #   }]
    #   quality: "high"
    #   resolution: "custom"
    # }
  end




  def self.create_video(payload)
    # url          = URI(MOVIES_ENDPOINT)
    # # params = { "x-api-key": ENV['JSON2VIDEO_KEY'] }
    # # url.query = URI.encode_www_form(params)
    # http         = Net::HTTP.new(url.host, url.port)
    # http.use_ssl = true
    # header = {'Content-Type': 'application/json', "X-Api-Key": ENV['JSON2VIDEO_KEY'] }
    # request                  = Net::HTTP::Post.new(url, header)
    # # request.content_type     = 'application/json'
    # # request["x-api-key"]     = ENV['JSON2VIDEO_KEY']
    # # request["accept"]        = request["content-type"] = 'application/json'
    # request.body             = payload.to_json
    # # puts "request API key #{request.to_hash }"
    # response                 = http.request(request)
    # puts "request API key #{request.body }"
    # data                     = JSON.parse(response.body)

    response = HTTParty.post(MOVIES_ENDPOINT, body: payload.to_json, headers: {"x-api-key": "#{ENV['JSON2VIDEO_KEY']}", "content-type": "application/json"})
    # puts response
    puts "Payload #{response}"
    response = HTTParty.get(MOVIES_ENDPOINT+'?id=rand-id', headers: {"X-Api-Key" => "L9ADvKIPrS7d7QgaURfsy4beQk3WHu4OorTrA17b" })

    results = HTTParty.get("https://api.json2video.com/v2/movies?id=rand-id", headers: {'x-api-key': 'L9ADvKIPrS7d7QgaURfsy4beQk3WHu4OorTrA17b', 'X-Api-Key': 'L9ADvKIPrS7d7QgaURfsy4beQk3WHu4OorTrA17b'})

    require 'uri'
require 'net/http'

uri = URI('https://api.json2video.com/v2/movies?id=rand_id','x-api-key=L9ADvKIPrS7d7QgaURfsy4beQk3WHu4OorTrA17b')
res = Net::HTTP.get_response(uri)

    # https://api.json2video.com/v2/movies
  end


  # url          = URI(GENERATION_ENDPOINT)
  # http         = Net::HTTP.new(url.host, url.port)
  # http.use_ssl = true

  # request                  = Net::HTTP::Post.new(url)
  # request["accept"]        = request["content-type"] = 'application/json'
  # request["authorization"] = "Bearer #{ENV['LEONARDO_KEY']}"
  # request.body             = payload.to_json
  # response                 = http.request(request)
  # JSON.parse(response.body)


  def self.create_scene_payload(scene, story_type)
    result = []
    scene.images_data.each do |image|
      result_obj              = {}
      element_obj             = {}
      result_obj["elements"]  = []
      element_obj["src"]      = image["url"]
      element_obj["type"]     = "image"
      element_obj["zoom"]     = 2
      element_obj["width"]    = story_type.output_width
      element_obj["height"]   = story_type.output_height
      element_obj["duration"] = 5
      element_obj["position"] = "center-center"
      result_obj["elements"] << element_obj
      result << result_obj
    end
    result
  end
end



# What JSON sends to json2video 

# {"id":
# "recQ5gYkgiDJA9J1Z","fps":25,"cache":false,"draft":false,"width":1920,"height":1080,
# "scenes":[
#   {"elements":[
#     {"src":"https://v5.airtableusercontent.com/v3/u/32/32/1725264000000/bnZM9pNud5TtpaLFgU9jUQ/aU_7u_9e-gnMJPA8a_o6VflRfRgxaINqXFeJpc00qkx63962iwrPHhpn-QkI1K8kPvQGon2ldx-i9iugsksKk6eGfSxoz7SYorILNqaNq-E8AnGpwVKJOrbHlRBfxHAQBIOsSTWtO71mV4gll2oTYKC6wj-fb8RJ4tGorKqde3LuZ58A_SEfvRGS6M_mwMFd2OLMr5s-ddaABJ5TerSiozxiK6gZjWk23qVQCpt8qSs/UNuv-RtUbA5NDhlVAzHCxpCZJ6GV9IY9fkNniFQke0I",
#     "type":"image",
#     "zoom":2,
#     "width":1920,
#     "height":1080,
#     "duration":5,
#     "position":"center-center"}]},
#   {"elements":[
#     {"src":"https://v5.airtableusercontent.com/v3/u/32/32/1725264000000/7LRHTN--OBjsLLhrYAti0Q/2WupE7D7oM1oUzEofjlHyrGlnqMr3TQCeghewpmLPuu9uxX_TKZBw0G4BzbVi0-Ti_kW-dPJb4DwNJO8HmoDD65PYmWaSvbm23RR08dJwC4JyRh9ai__BbZi_5fkv6QY8C5aqO1CF0EyevyX-kTajTz7Cn1GlXD81WGmdNi5xLC7uhQdhwLNBus8elXyzygR-y4Fx_UypB_2SPZDgni0KXTcNxWoV7AaxN_Lq1ck-38/DY1SObUg-uuY-LKqTeAbEsyif_LqZFdVr1hBB0hJjCE",
#     "type":"image",
#     "zoom":2,
#     "width":1920,
#     "height":1080,
#     "duration":5,
#     "position":"center-center"}]},
#   {"elements":[{"src":"https://v5.airtableusercontent.com/v3/u/32/32/1725264000000/_A5AaRBkA7dz46wC9eGrtg/hlmizF4lVvrkmwZvFEgFTG29doU9a8BJZoGl2i9V2ETtRTOLT1qruX78cCrRNZzH70_xynhKOjY4ZPu5qGONIvYTRGxeqcvFf81-eoe7Hm44hvEQ2cWKQRM3QuC565capKONMDfGv_et3EzU5Y4zBa3m-a33U6fb9CXnNJPJ4WrWoTqLB0XLsSR93MzLdD1Ny6_tu3VqjGWv04vkr544F7jqJijrpd_TTTnjy9HfQ2U/2zxSRtX_L7oH2xJrlc6iqQ7DVobFQ1vFZZCQ7492H6g","type":"image","zoom":2,"width":1920,"height":1080,"duration":5,"position":"center-center"}]},{"elements":[{"src":"https://v5.airtableusercontent.com/v3/u/32/32/1725264000000/RV-EK6ehnykkVJR4mmR3mA/c2l54SDb5PKQ7YoXW-ApX-tmZIBbvn9j6UzCfY_Ej2ie5PXUWqdpvT_2ePbni5sGfdWkrk5uReIaoOXW-at4Pt1PybevxOsuAQ59YPQ9Xj5ELgFdoRfQ3ivSwiAALZG78nQG-SHrPsu7qNd03v4rwWitlTKm1KaB_2G6xLEUAPghK5TAuYgAlbzJWdcPFVASNrKfT9WwvX-zwwqDNh2zV99azWRzlE2yIVgK0qGPW4w/kesT-PRjbG1JvAIlhHJnSt9OcbuYByw5JPhUsq1Rs8M","type":"image","zoom":2,"width":1920,"height":1080,"duration":5,"position":"center-center"}]},{"elements":[{"src":"https://v5.airtableusercontent.com/v3/u/32/32/1725264000000/8fxHBMGn17sg_GAK8mMU9Q/ihipeDrA1PDqxTz3deFlKnDsSd8IFQP_xAYKssTU9gedG7ZkNyWgu8w0e8uH26mQzsR96gJYyqcsxqF4AW_CUq3p3JLm6Vw6L2Y31AK1HKHitifzhU70KIkdCNoF5s8KifantF_KVUOHl4tIbSAenkVkVVnzIQyuu58ZPmkQT1apu7JJFYJBWkFBfMP-vN5oSc1ch3eyBmE-WQpnpPWmNKoNNJ5vRj_3k1layCNECxc/at63FzWkJRsr1SuNudxMGDaRlCQ5eVH8u1JJg62Ybl0","type":"image","zoom":2,"width":1920,"height":1080,"duration":5,"position":"center-center"}]},{"elements":[{"src":"https://v5.airtableusercontent.com/v3/u/32/32/1725264000000/7IW8mCDGV2lebzyo9qM44A/hFDnH5xTTv_i2ExJIV3OKWQ5YuUuFbnXstAXGE55VvkIMSGhrQ3TgozWtB49bgsGJUTwThh28kgbi5ac4etoPU94T-n9QvIqnPQGhqNYQNxy6ZO6EhSu4hW4LINel-VdRXezVHO-ULcexNGE2O5aGhVxU7bU-hPz_Va6HAimOC0oD7a4YrhMy4FFGT0VsNBVViKylfynVIQuW3cgz6PEKxby-hggVNfDeLR7peTqyzU/zKahE8Wcy26KRCMEPslmyXFIYAV7SE54ROrp0n6p0C0","type":"image","zoom":2,"width":1920,"height":1080,"duration":5,"position":"center-center"}]},{"elements":[{"src":"https://v5.airtableusercontent.com/v3/u/32/32/1725264000000/dzhRpxR2vXA4fKo9v1dmsA/VfiNg9-l4H0JabhuYCK57esvQ-LobPsd1vUst3d9V3cKWG4MQv_gdMFx2QabGYtGA0O4qKTy8spjQ1ZXs8G3F2KtK1LP9Ot1BcOuWktqy_uLVoUe50qKJsGKQos9Tac2E3rLlBZT7gRN3XDjE8gwbGkfcMG0ZMRo0UCv1zckZ3bhk5FpGweLtRPRG44hWcfKfTof13yk1jidQipEDfkLGsv4AzvSXelChOF9WmyNHqA/Q-VaS00ZPhH3LpW1Ai7RQ5NyR13ix90J7NY-x9MC-jM","type":"image","zoom":2,"width":1920,"height":1080,"duration":5,"position":"center-center"}]},{"elements":[{"src":"https://v5.airtableusercontent.com/v3/u/32/32/1725264000000/0ezV9AVKboNS9zKDJVGUzQ/4Igmtk3ueEmSCbLa2EFmFx8mEQUcjJKN11typ3K24lVjCHeXBBblLPcKzRT8qhj3h3zv4KGynGu9MF4FQPay-Tn1X6Q6za3eMJKe1vpSseJgIh1omU_45sTcwy7uKNzgXe0zzoyhEuX0zM0AXDNhO-iCc2VEC1bioaI23_hOxgxKcHkWG3LdbQJHYIJgXQXDdj57GJW-FgI54AcVk1_j5A0sxVmKMRtft-jkd7k48EE/tAk4PoxMRgK3uUYzPKtsUHUP5e6_IWwx1xJ6D5kycn0","type":"image","zoom":2,"width":1920,"height":1080,"duration":5,"position":"center-center"}]},{"elements":[{"src":"https://v5.airtableusercontent.com/v3/u/32/32/1725264000000/cPd54c86xSx7KkPhsKIjUA/YvIMbF00SP51Vxb8Qsf7HYF_DI8Dn0TGH5PD1JaGxMExCG-4Cu_m6WhJQCMuWjA8E_vl1-qlNmV1Y6f_YFhl-HcnWExzThoVeMTQaGcmDE7IgKgYu72Mm6GGqBbtyWTAnCgiJKJu3gHS4dCfUFAXAg011e75FtiFK0qrUSPWaicH13vHyfM4i1Z1AsYXmjJ36DVa_g2Zgg-YGKAD8_zlfv2rgkvFPq3pMx6DlrzwXKQ/3WwNamT0pRlEy9Tuc3Hhj38MkY0jmGU3RSTWFgYf80U","type":"image","zoom":2,"width":1920,"height":1080,"duration":5,"position":"center-center"}]}],"exports":[{"destinations":[{"type":"webhook","endpoint":"https://hooks.airtable.com/workflows/v1/genericWebhook/app17miNPZN6KewDx/wfl9ybUNjugCnNsbk/wtrIJ2KxjmORTBvG5","Content-Type":"application/json"}]}],"quality":"high","elements":[],"settings":{},"resolution":"custom"}





# [
#     {
#         "ca": null,
#         "qs": [],
#         "url": "https://api.json2video.com/v2/movies",
#         "data": "{\"id\":\"recQ5gYkgiDJA9J1Z\",\"fps\":25,\"cache\":false,\"draft\":false,\"width\":1920,\"height\":1080,\"scenes\":[{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725292800000/znMD_dBllwPGvsdrjko-Rg/V0v9bSrt3g26_6STzGfx7QbPqYjXrQe9wU10Ah4Dzpt6SxyE65STZBgsWrj2We2NNscSpMiAL68H7tgS-ac8fwvS8G1T0zanZZ_CmEPpUQXU8AUhnIwhpj4VHFKsIOmjVQ4T0b_I1pUBFleJhsRo_fKlbWWFR50WPkStYZimvIUGg4H4kTQpn2A6EFgj-uEWwFV_7onot4w6cOeLIFUd1c_ZIoqeDNFCLzaO4oS8ILw/0R_wR0dQM_VgkZ8ykfvAOOuX6zcq3-Gmg8371yeEKIs\",\"type\":\"image\",\"zoom\":2,\"width\":1920,\"height\":1080,\"duration\":5,\"position\":\"center-center\"}]},{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725292800000/2SP3DwpS2CzSbCQpHVmfxQ/F9t60ahHaklgu_kY-hw0VeyIJih__kYVGxrtyt1on2ISiaK8CWQg4QMfqjADEx_IyeOjQp0TqnMWlJrGiGf3E6VTnF5JyYwVndQR-kTmjGcFiiOQGQE5aDzRoY4FiTcY2NmLQK2kjEkVv4PSVXULl5CniRJwLRxdPYrhU8vRRGb8ucBPvZVzoZ2v9L-biFuf3RtWhs1j3o673XAY_0dmrK6y2eFHx7SDqLlh_N3dnto/m_wpfODNkn_HHhQrdNKCZM7z3ncCIK83Fq1QpFmbqGQ\",\"type\":\"image\",\"zoom\":2,\"width\":1920,\"height\":1080,\"duration\":5,\"position\":\"center-center\"}]},{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725292800000/EzHhzW3dZLLTP8g60DW2pA/B7g6Q2VWKZ8qhlZx8h11bE-JniB5jbyAlRqQm5ANCaFC-izbS9tyTuNr9Q5asfN-ccH_CiEmwnDciFd8SaSlvMhM3G7lSPZyC-WDt0FeXYg_WausCeSFtOknc1wNNpYseOrpBbySqMmveMotIHXY_qJiTiq2zp1bATUmzHVWg8k-hn8b05Ht1yApK6CRGip21Hha4p7pkLo7mI9yDKdLwgNgDf75U9ig6P0n8rHqEwU/kaxa8lbHqUcZ1-B5hep54ftbXGWHg7EWtvosmpMkqTk\",\"type\":\"image\",\"zoom\":2,\"width\":1920,\"height\":1080,\"duration\":5,\"position\":\"center-center\"}]},{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725292800000/oP5F72GZpvSpr5ODyas0Jg/3FqwKfcNE96hV8GEoJFOVTSBQSr1ktd41suIdZUrK-P7AcOOHNI2s1G1TCF2O88Oe7ZBo5Xj1HdzdKwRfY5D188rwGb_IL4PEDPVAC_9bzUcNeH5NaUWqc_VZFvPXBvzzQkam-9cNuFw3sYGwFk09I3g81T-O8q3-sXxn_xY95i7G1JlWcxWxzMIhg8XzxjegjU1ZcyJpJSMltlGQ7_ygTC8U98lEU7G1BqTe3TSEl8/cx6n2FT_EQyjGtP7WceKs-6WaLwSwG_C951J677sGGU\",\"type\":\"image\",\"zoom\":2,\"width\":1920,\"height\":1080,\"duration\":5,\"position\":\"center-center\"}]},{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725292800000/qntoVQqy6CW7hJSXvKxX4A/9aTFyNnOAZNTNZwyPyGwilTMVL30cymhLVwglHCZ2udXaeb80Pr3Foq9faZeS4KKDrqY3f3uuV0N7F08tinK9jl6OFzGn6hk3j3EElb5J7unQZATOc2Po_VCGTMtLw7V8sMr34iwGdOpE_SL3F2go8doKzeaK7t91cYM0FynYyRcwKfcPpj_wKm1p1zPGQEYQPlpTBLdSiSFCtGaJvvtTPkGDB3Ze8BCUR0p6dWD-aE/pVJEwEv6CtKrzW6sZkgvGnQhNA67LA1K-loYbZ5hdSY\",\"type\":\"image\",\"zoom\":2,\"width\":1920,\"height\":1080,\"duration\":5,\"position\":\"center-center\"}]},{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725292800000/J3JKE9vtUi32AwmtxmhVEg/bKdJR5SwHmqDEU-F8nNX_9QWOiF7P_Oom9e0W87UQEEsPk5sXqF9Cgw1VibK1OYRuTaELev7G8EwVSAvf3IInWXvR4Ebw3WdqwEF6OcLUKOAsI2O3AO_adt2SQolPKUaR29g3gSdexeDAYjt4yBA0UQvvUaft8JMZ7m9x5GsrrRIqDL-yal2m4kyI0Fb-lsuwZHu8AxxiWEePnjOk1-TgLO0vydtDmBkD87oL64bI8Y/_Zt3jN5ZmAoXXu2iPk03KWixY34EsbATFJFONERATlY\",\"type\":\"image\",\"zoom\":2,\"width\":1920,\"height\":1080,\"duration\":5,\"position\":\"center-center\"}]},{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725292800000/Gz0k4R6MwJq2Yrp8-Et5Mw/y-Lgl6GPDy_A0--5GTPHNG12t0fTcxL47Toh8op1ck0a3EcbEEO__352mKpS7LsQQ60eEltkbjHxWMW-Cqlc1VwC7JkNyGecKu5huVdXHf8OKKUpZ1t2hVCwHvi2eav6EEsLOtbsy_k5M7SIQI6UA_T7BGdXNmWKoyWQKfEUwIgCTDs4Z51ipY37vwvpMuaIiiZRE1GPY6VeBihgdQsod_omvKU3N67u34KLh8ELGfM/LiaoY2tSIbT1elmfcqYd2vg2bzvt9WlFRrS5lHTdHNQ\",\"type\":\"image\",\"zoom\":2,\"width\":1920,\"height\":1080,\"duration\":5,\"position\":\"center-center\"}]},{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725292800000/uIiL37wutlbphHIEGGo2rQ/gOdwLprN1eRY-eP6My73GbDVO-aP2JAK560Udl98KRf3uZ7YMX9Y9gLSLibGHjC5N_XJQS10KVq4mYOiOiwVJJAAmvxJ2mS0YlTJnD-oBs1dVXJQBDrhGIzayyUepML_O3LCRVnr6eYkZRP39B9q1hBr7tu82MLXH5oQ4pSsz-Wjd9zx1UsXCGc8H-5IrK_r7eqNjl1ur6YfEz96g-vZ5TimS7zUGcC07P6HauJi4M0/FA0V7-ujb-4SOV0uw_3r-lIsnu0mXd17hG2Kh3zL_7E\",\"type\":\"image\",\"zoom\":2,\"width\":1920,\"height\":1080,\"duration\":5,\"position\":\"center-center\"}]},{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725292800000/AeeBfkuG0cJyNu5fweB6eg/ayRAGsVkIG6GovLlwx2WqKG6ODMDya89dtnonnb36wDcUuanVfefHJzVTyd1_42-WIE-EP3kUpmQEgV6XgfIz8sOrgoZdoM54wDCuI3JgJzh9OKUUOuvSpelnfbmOg29rxScfHJ7qNDB7zWyXAHACJvxyUMaQoUBtaNLcEAjKp7JLKpYfejft39UIOXFWejd3nEaEOSuhF77sdv4xfy4tMSoVtHE1NLWS2F3OW2uqD0/gYLOx7djm9FcYm3YjsjAYwBJq67qozBVb_fBBqRHi3s\",\"type\":\"image\",\"zoom\":2,\"width\":1920,\"height\":1080,\"duration\":5,\"position\":\"center-center\"}]}],\"exports\":[{\"destinations\":[{\"type\":\"webhook\",\"endpoint\":\"https://hooks.airtable.com/workflows/v1/genericWebhook/app17miNPZN6KewDx/wfl9ybUNjugCnNsbk/wtrIJ2KxjmORTBvG5\",\"Content-Type\":\"application/json\"}]}],\"quality\":\"high\",\"elements\":[],\"settings\":{},\"resolution\":\"custom\"}",
#         "gzip": true,
#         "method": "post",
#         "headers": [
#             {
#                 "name": "x-api-key",
#                 "value": "L9ADvKIPrS7d7QgaURfsy4beQk3WHu4OorTrA17b"
#             }
#         ],
#         "timeout": null,
#         "useMtls": false,
#         "authPass": null,
#         "authUser": null,
#         "bodyType": "raw",
#         "contentType": "application/json",
#         "serializeUrl": false,
#         "shareCookies": false,
#         "parseResponse": true,
#         "followRedirect": true,
#         "useQuerystring": false,
#         "followAllRedirects": false,
#         "rejectUnauthorized": true
#     }
# ]


Net::HTTP.post URI('http://localhost:3000'),
               { "q" => "ruby", "max" => "50" }.to_json,
               {"X-Api-Key" => "L9ADvKIPrS7d7QgaURfsy4beQk3WHu4OorTrA17b",
                "bodyType" => "raw", "contentType": "application/json"}




