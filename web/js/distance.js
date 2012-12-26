   function set_start_loc(latlon){
  var ss = latlon.toString().match(/[\d\.\-]+/g);
  document.inputform.latitude.value = ss[0];
  document.inputform.longitude.value = ss[1];
  measure_distance();
}
function set_end_loc(latlon){
  var ss = latlon.toString().match(/[\d\.\-]+/g);
  document.inputform.latitude_end.value = ss[0];
  document.inputform.longitude_end.value = ss[1];
  measure_distance();
  return true;
}
function measure_distance(){
  if (typeof(Number.prototype.toRad) === "undefined") {
  Number.prototype.toRad = function() {
    return this * Math.PI / 180;
  }
  }
  if( document.inputform.latitude.value && document.inputform.latitude_end.value &&
     document.inputform.longitude.value &&document.inputform.longitude_end.value){
  var lat_start = parseFloat(document.inputform.latitude.value);
  var lat_end = parseFloat(document.inputform.latitude_end.value);
  var lon_start = parseFloat(document.inputform.longitude.value);
  var lon_end = parseFloat(document.inputform.longitude_end.value);
  
  var R = 6371; // km
  if(document.inputform.unit.value == "Miles"){
    R = 3958.7558657440545;
  }
  
  var dLat = (lat_end - lat_start).toRad();
  var dLon = (lon_end - lon_start).toRad();
  var lat1 = lat_start.toRad();
  var lat2 = lat_end.toRad();

  var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.sin(dLon/2) * Math.sin(dLon/2) * Math.cos(lat1) * Math.cos(lat2); 
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
  var d = R * c;
  document.inputform.distance.value = roundVal(d);
  }
}

function roundVal(val){
	var dec = 2;
	var result = Math.round(val*Math.pow(10,dec))/Math.pow(10,dec);
	return result;
}