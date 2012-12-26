//Copyright 2011 Jesse Crocker

function set_start_loc(latlon){
  var ss = latlon.toString().match(/[\d\.\-]+/g);
  if(document.inputform.latitude ){
    document.inputform.latitude.value = ss[0];
    document.inputform.longitude.value = ss[1];
  }
}
function set_end_loc(latlon){
  var ss = latlon.toString().match(/[\d\.\-]+/g);
  if(document.inputform.latitude_end){
    document.inputform.latitude_end.value = ss[0];
    document.inputform.longitude_end.value = ss[1];
    return true;
  }else{
    return false;
  }
}
function check_species_other(){
  if(document.inputform.species.value == "other"){
    var el_r = document.getElementById("species");
    el_r.parentNode.removeChild(el_r);
    var new_el = document.createElement('input');
    new_el.type = "text";
    new_el.size = "30";
    new_el.name = "species";
    document.getElementById("species_span").appendChild(new_el);
  }
}
function check_activity_other(){
 if(document.inputform.activity.value == "other"){
    var el_r = document.getElementById("activity");
    el_r.parentNode.removeChild(el_r);
    var new_el = document.createElement('input');
    new_el.type = "text";
    new_el.size = "30";
    new_el.name = "activity";
    document.getElementById("activity_span").appendChild(new_el);
  }
}

function set_update_markers(){
  if(document.inputform.latitude &&document.inputform.latitude.value && document.inputform.longitude.value){
    parent.set_click_marker_string(document.inputform.latitude.value + "," + document.inputform.longitude.value);
  }
  if(document.inputform.latitude_end && document.inputform.latitude_end.value && document.inputform.longitude_end.value){
    parent.set_click_marker_string(document.inputform.latitude_end.value + "," + document.inputform.longitude_end.value);
  }
}
function clear_start_marker(){
  parent.clear_click_marker();
  document.inputform.latitude.value = "";
  document.inputform.longitude.value = "";
}
function clear_end_marker(){
  parent.clear_click_marker_end();
  document.inputform.latitude_end.value = "";
  document.inputform.longitude_end.value = "";
}
function update_total(){
  if(!document.getElementsByClassName){
    document.getElementsByClassName = function(cl) {
      var retnode = [];
      var myclass = new RegExp('\\b'+cl+'\\b');
      var elem = this.getElementsByTagName('*');
      for (var i = 0; i < elem.length; i++) {
        var classes = elem[i].className;
        if (myclass.test(classes)) retnode.push(elem[i]);
      }
      return retnode;
    }; 
  }
  
  var count_fields = document.getElementsByClassName("count_field");
  var totalCount = 0;
  for(var i = 0; i < count_fields.length; i++){
    var thisCount = parseInt(count_fields[i].value);
    if(thisCount){
      totalCount += thisCount;
    }
  }
  document.inputform.total.value = totalCount;
}

function check_length(el){
  if (el.value.length == el.maxLength){
    var next;
    var elements = document.getElementById("inputform").elements;
    for(var i = 0; i < elements.length; i++){
      if(el.tabIndex + 1 == elements[i].tabIndex){
        next = i;
        break;
      }
    }
    if (next && next<document.getElementById("inputform").length){
      document.getElementById("inputform").elements[next].focus();
    }
  }
}
