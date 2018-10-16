
data = {
  "events" => [
    ['success','success_detail','20'],
    ['failure','failure','30'],
    ['audit','audit','40'],
    ['noop','noop','10'],
    ['total','total','100']
  ]
}


metrics = {
  "time" => {
    "config_retrievel" => "",
    "total" => "",
  },
  "events" => {
    "success" => [""],
    "failure" => "",
    "audit" => "",
    "noop" => "",
    "total" => "",
  },
  "changes" => "",
}

metrics['events'].each_key { |key|
  results = data["events"].select {|val| val[0] == key }
  metrics['events'][key] = results[0][2]
}

puts metrics