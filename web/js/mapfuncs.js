//Copyright 2011 Jesse Crocker

var map;
var infoWindow;
var today = new Date();
var lastWeek = new Date();
lastWeek.setDate(today.getDate() - 7);

var iconbase = "images/markers/";
var icons_static = {};
icons_static["landmark"] = "landmark.png";
icons_static["default"] = "mm_20_black.png";

var icons_available_nomod = ['mm_20_blue.png', 'mm_20_brown.png', 
			     'mm_20_gray.png', 'mm_20_orange.png',
			     'mm_20_purple.png', 'mm_20_yellow.png', 
			     'mm_20_darkpurple.png', 'mm_20_darkgreen.png',
			     'mm_20_lightblue.png', 'mm_20_green.png',
			     'mm_20_red.png', 'mm_20_white.png' ];
var icons_available;
var icons_used;

var startIcon;
var endIcon;
var clickmarker;
var clickmarker_end;

var query_type;
var myMarkers;
var myMarkersHTML;
var lastclick = "" ;

var myLayers;
var myParcels;

var popupWin;
var reportHTML;
var layer_legend_info;
var loadingMessage;
var filesLoading = 0;
var filesLoaded = 0;
var countfields;
var can_report_sighting = 0;
var progress_bar;

/////         Core functions
function load() {
  if(conf['logged in'] == 1){
    set_logged_in();
  }else{
    set_logged_out();
  }
  
  if(conf['admin'] == 1){
    set_admin();
  }
  
  if(conf['post'] == 1){
    set_can_report_sightings();
  }
  
  setDate(lastWeek, today);
  
  var myOptions = {
    zoom: parseInt(conf['default zoom']),
    center: new google.maps.LatLng(conf['default latitude'], conf['default longitude']),
    //disableDefaultUI: true,
    streetViewControl: false,
    mapTypeId: google.maps.MapTypeId.TERRAIN,
    mapTypeControl: true,
    zoomControl: true
  }

  map = new google.maps.Map(document.getElementById("mapdiv"), myOptions);
  
  google.maps.event.addListener(map,"click",function(event){
          checkclick(event.latLng);
    });
    
  infoWindow = new google.maps.InfoWindow();
    
  countfields = conf['countfields'].match(/[^,]+/g);
  choose_search_form();
  updateMap();
}

function updateMap(){
  if(filesLoading <= 0){ //map is not in the proccess of updating 
    filesLoading = 0; //it should be 0 when we get here, but might as well set it in case it ended up less than 0
    filesLoaded = 0;
    show_loading_message();
    var baseurl="qs.pl?format=wildlifedb&";
    reportHTML = '<html><head><title>Sighting Report</title><link href="css/report.css" rel="stylesheet" type="text/css" /><script type="text/javascript" src="js/sortable/common.js"></script><script type="text/javascript" src="js/sortable/css.js"></script><script type="text/javascript" src="js/sortable/standardista-table-sorting.js"></script></head><body><table class="sortable"><thead><tr><th>Open Start</th><th>Open End</th><th>Reported by</th><th>Species</th><th>Start Date</th><th>Start Latitude</th><th>Start Longitude</th><th>End Date</th><th>End Latitude</th><th>End Longitude</th><th>Activity</th>';
    for (var i = 0; i < countfields.length; i++){
      reportHTML += "<th>" + countfields[i] + "</th>";
    }
    reportHTML += '<th>Notes</th></tr></thead><tbody>';
    myClear();
    
    //load layers
    if(document.menu_form.layers){
      if(document.menu_form.layers.length){
	for (var i = 0; i < document.menu_form.layers.length; i++){
	  if(document.menu_form.layers[i].checked){
	    load_layer_file(document.menu_form.layers[i].value);
	  }
	}
      }else{
	if(document.menu_form.layers.checked){
	    load_layer_file(document.menu_form.layers.value);	  
	}
      }
    }
    
    //load landmarks
    if(document.menu_form.landmarks.checked){
      icons_used['landmark'] = icons_static['landmark'];
      load_landmark_file("q-landmark.pl?format=wildlifedb", iconbase + icons_static['landmark']);
    }
    
    //load private property
    if(document.menu_form.parcels.checked){
      var bounds = map.getBounds();
      if(bounds){
        var sw = bounds.getSouthWest();
        var ne = bounds.getNorthEast();
        var url = "q-parcel.pl?format=wildlifedb&limit=5000&owner_code=10000&sw_corner=" + sw.toUrlValue() + "&ne_corner=" + ne.toUrlValue();
	load_parcel_file(url);
      }
    }

    //load sigtings
   var mapcords = map.getCenter().toUrlValue().match(/[\d\.\-]+/g);
    if(query_type == "range_form"){
      for (var i = 0; i < document.menu_form.r_species.length; i++){
	if(document.menu_form.r_species[i].selected){
          var url = baseurl + "species=" + document.menu_form.r_species[i].value +
          "&startdate=" + document.menu_form.r_startyear.value +
          "-" + document.menu_form.r_startmonth.value + "-" + 
          document.menu_form.r_startday.value +
          "&enddate=" + document.menu_form.r_endyear.value + "-" +
          document.menu_form.r_endmonth.value + "-" + document.menu_form.r_endday.value +
          "&activity=" + document.menu_form.r_activity.value + 
          "&centerlat=" + mapcords[0] + 
          "&centerlon=" + mapcords[1] + 
          "&centerdist=" + document.menu_form.centerdist.value + 
          "&limit=" + document.menu_form.limit.value;
          loadMarkerFile(url);
	}
      }
    }else if(query_type == "series_form"){
      for (var i = 0; i < document.menu_form.s_year.length; i++){
	if(document.menu_form.s_year[i].selected){
	  var year = document.menu_form.s_year[i].value;
	  var url = baseurl + "startdate=" + year +
	    "-" + document.menu_form.s_startmonth.value + "-" + 
	    document.menu_form.s_startday.value +
	    "&enddate=" + year + "-" +
	    document.menu_form.s_endmonth.value + "-" + 
	    document.menu_form.s_endday.value +
	    "&species=" + document.menu_form.s_species.value + 
	    "&centerlat=" + mapcords[0] + 
	    "&centerlon=" + mapcords[1] + 
	    "&centerdist=" + document.menu_form.centerdist.value +
	    "&limit=" + document.menu_form.limit.value;
	  var iconurl = getIconUrl(document.menu_form.s_species.value + " " + year);
	  loadMarkerFile(url, iconurl);
	}
      }
    }else if(query_type == "my_sightings"){
      var url = baseurl + "mysightings=1";
      loadMarkerFile(url);
    }else if(query_type == "name_form"){
      var url = baseurl + "username=" + document.menu_form.username.value +
      "&limit=" + document.menu_form.limit.value;
      loadMarkerFile(url);      
    }else{}
  }else{
    //    alert("The map is already updating.");
  }
  hide_loading_message();
}

function viewInEarth(){
  var baseurl="qs.pl";
  var mapcords = map.getCenter().toUrlValue().match(/[\d\.\-]+/g);
  
  if(query_type == "range_form"){
      var species = "";
      for (var i = 0; i < document.menu_form.r_species.length; i++){
	if(document.menu_form.r_species[i].selected){
	  if(species){
	    species += ":";
	  }
	  species += document.menu_form.r_species[i].value;
	}
      }
      var url = baseurl + "?format=kml" + 
      "&startdate=" + document.menu_form.r_startyear.value +
      "-" + document.menu_form.r_startmonth.value + "-" + 
      document.menu_form.r_startday.value +
      "&enddate=" + document.menu_form.r_endyear.value + "-" +
      document.menu_form.r_endmonth.value + "-" + document.menu_form.r_endday.value +
      "&multiple_species=" + species + 
      "&activity=" + document.menu_form.r_activity.value + 
      "&centerlat=" + mapcords[0] + 
      "&centerlon=" + mapcords[1] + 
      "&centerdist=" + document.menu_form.centerdist.value + 
      "&limit=" + document.menu_form.limit.value;
      open_earth_url(url);
    }else if(query_type == "series_form"){
      var years = "";
      for (var i = 0; i < document.menu_form.s_year.length; i++){
	if(document.menu_form.s_year[i].selected){
	  if(years){
	    years += ":";
	  }
	  years += document.menu_form.s_year[i].value;
	}
      }
      var url = baseurl + "?format=kml" +
	"&multiple_years=" + years +
	"&startdate=" + document.menu_form.s_startmonth.value + "-" + 
	    document.menu_form.s_startday.value +
	    "&enddate=" + document.menu_form.s_endmonth.value + "-" + 
	    document.menu_form.s_endday.value +
	    "&species=" + document.menu_form.s_species.value + 
	    "&centerlat=" + mapcords[0] + 
	    "&centerlon=" + mapcords[1] + 
	    "&centerdist=" + document.menu_form.centerdist.value +
	    "&limit=" + document.menu_form.limit.value;
      open_earth_url(url);
    }else if(query_type == "my_sightings"){
      var url = baseurl + "?format=kml&mysightings=1";
      open_earth_url(url);
    }else if(query_type == "name_form"){
      var url = baseurl + "?format=kml&username=" + document.menu_form.username.value +
      "&limit=" + document.menu_form.limit.value;
      open_earth_url(url);
    }else{}
}

function parcelsInEarth(){
  var bounds = map.getBounds();
  if(bounds){
    var sw = bounds.getSouthWest();
    var ne = bounds.getNorthEast();
    var url = "q-parcel.pl?format=kml&limit=5000&owner_code=10000&sw_corner=" + sw.toUrlValue() + "&ne_corner=" + ne.toUrlValue();
    open_earth_url(url);
  }
}

function open_earth_url(url){
  window.open(url,'','scrollbars=no,menubar=no,height=100,width=100,resizable=yes,toolbar=no,location=no,status=no');
}

function loadMarkerFile(url, iconurl){
  add_file_loading();
  var request = new XMLHttpRequest();
  request.onreadystatechange = function() {
    if (request.readyState==4 && request.status==200){
      var xmlDoc = request.responseXML;
      // obtain the array of markers and loop through it
      var markers = xmlDoc.documentElement.getElementsByTagName("marker");
      for (var i = 0; i < markers.length; i++ ) {
	// obtain the attribues of each marker
	var mark = markers[i];
	var species = mark.getAttribute("species");
	var html = "";
	var html_end = "";
	if(mark.getAttribute("image")){
	  html +=  "<img class='markerimg' width='" + mark.getAttribute("image_width") + 
	    "' height='" + mark.getAttribute("image_height") + "' src='" + mark.getAttribute("image") + "' />";
	  html_end +=  "<img class='markerimg' width='" + mark.getAttribute("image_width") + 
	    "' height='" + mark.getAttribute("image_height") + "' src='" + mark.getAttribute("image") + "' />";
	}
	html += "<div>" + species + "<br /> Activity: " + mark.getAttribute("activity")
	  + "<br />Date: " + mark.getAttribute("date");
	html_end += "<div>" + species + "<br /> Activity: " + mark.getAttribute("activity")
	  + "<br />Date: " + mark.getAttribute("date_end");
	//iterate through children of marker to get counts, put them in a hash
	var counts = new Object();
	if(mark.hasChildNodes){
	  for(var n = 0; n <mark.childNodes.length; n++){
	    var node = mark.childNodes[n];
	    if(node.attributes){
	      var count = parseInt(node.textContent);
	      var cname = node.getAttribute("name");
	      counts[cname] = count;
	      if(count > 0){
		html += "<br />" + cname + ": " + count;
		html_end += "<br />" + cname + ": " + count;
	      }
	    }
	  }
	}
	if(mark.getAttribute("notes")){
	  html += "<br />Notes: " + mark.getAttribute("notes");
	  html_end += "<br />Notes: " + mark.getAttribute("notes");
	}
	if(mark.getAttribute("username")){
	  html += "<br />Reported by " + mark.getAttribute("username");
	  html_end += "<br />Reported by " + mark.getAttribute("username");
	}
	if(mark.getAttribute("update_link")){
	  html += "<br /><a target=input_frame onclick=openFrame() href=" + 
	    mark.getAttribute("update_link") + 
	    ">Update</a> / <a target=input_frame onclick=openFrame() href=" + 
	    mark.getAttribute("delete_link") +
	    ">Delete</a>";
	  html_end += "<br /><a target=input_frame onclick=openFrame() href=" + 
	    mark.getAttribute("update_link") + 
	    ">Update</a> / <a target=input_frame onclick=openFrame() href=" + 
	    mark.getAttribute("delete_link") +
	    ">Delete</a>";
	}
	var marker_number;
	var marker_number_end = 0;
	// create end marker
	myMarkers.push("");
	marker_number =  (myMarkers.length - 1);
	if(document.menu_form.show_end.checked &&
	   mark.getAttribute("latitude_end") &&
	   mark.getAttribute("longitude_end") &&
	   myMarkers.length < document.menu_form.map_max.value){
	  myMarkers.push("");
	  marker_number_end =  (myMarkers.length - 1);	
	  html += "<br><a href='javascript:openMarker(" +  marker_number_end + ")' >Open end</a>";
	  html_end += "<br><a href='javascript:openMarker(" +  marker_number + ")' >Open start</a>";
	  html_end += "</div>";
	  myMarkersHTML[marker_number_end] = html_end;
	  var point = new google.maps.LatLng(parseFloat(mark.getAttribute("latitude_end")), 
				  parseFloat(mark.getAttribute("longitude_end")));
	  var marker = createMarker(point, html_end, species, iconurl);
	  myMarkers[marker_number_end] = marker;
	}
	//create the start marker
	html += "</div>";
	myMarkersHTML[marker_number] = html;
	var point = new google.maps.LatLng(parseFloat(mark.getAttribute("latitude")),
				parseFloat(mark.getAttribute("longitude")));
	var marker = createMarker(point, html, species, iconurl);
	if(document.menu_form.map.checked && 
	   myMarkers.length < document.menu_form.map_max.value){
	}
	myMarkers[marker_number] = marker;

	//put sighting in report
	var miconurl;
	if(iconurl){
	  miconurl = iconurl;
	}else{
	  miconurl = getIconUrl(species);
	}
	var username = mark.getAttribute("username");
	if(!username){  
	  username = "";
	}
	var myReportHTML =  "<tr><td><a href='javascript:opener.openMarker(" + marker_number + ")'><img src='" + miconurl + "' /></a></td>";
	if(marker_number_end){
	  myReportHTML += "<td><a href='javascript:opener.openMarker(" + marker_number_end + ")'><img src='" + miconurl + "' /></a></td>"; 
	}else{
	  myReportHTML += "<td></td>";
	}
	myReportHTML += "<td>" + username +  "</td><td>" + species + "</td><td>" + mark.getAttribute("date") + "</td><td>" + mark.getAttribute("latitude") + "</td><td>" + mark.getAttribute("longitude") + "</td><td>" +  mark.getAttribute("date_end") + "</td><td>" + mark.getAttribute("latitude_end") + "</td><td>" + mark.getAttribute("longitude_end") + "</td><td>" + mark.getAttribute("activity") + "</td>";
	for (var cf = 0; cf < countfields.length; cf++){
	 myReportHTML += "<td>" + counts[countfields[cf]] + "</td>";
	}
	myReportHTML += "<td>" + mark.getAttribute("notes") + "</td></tr>"; 
	reportHTML += myReportHTML;
      }
      sub_file_loading();
    }
  }
  
  request.open("GET", url, true);
  request.send();
}

function load_layer_file(url){
  add_file_loading();
  var dynamic = url.match(/dynamic:(.*)/);
  if(dynamic){
    var bounds = map.getBounds();
    if(bounds){
      var sw = bounds.getSouthWest();
      var ne = bounds.getNorthEast();
      url = dynamic[1] + "sw_corner=" + sw.toUrlValue() + "&ne_corner=" + ne.toUrlValue();
    }
  }
  var gx = new google.maps.KmlLayer(url, {preserveViewport: true});
  gx.setMap(map);
  myLayers.push(gx);
  sub_file_loading();
}

function clear_layers(){
  if(myLayers){
    for(var i = 0; i < myLayers.length; i++){
      myLayers[i].setMap(null);
    }
  }
}

function myClear(){
  icons_available = new Array();
  for (var i = 0; i < icons_available_nomod.length; i++) {
    icons_available.push(icons_available_nomod[i]);
  }
  clear_click_markers();
  if(myMarkers){
    for(var i = 0; i < myMarkers.length; i++){
      if(myMarkers[i]){
        myMarkers[i].setMap(null);
      }
   }
  }
  
  if(myParcels){
    for(var i = 0; i < myParcels.length; i++){
      if(myParcels[i]){
	myParcels[i].setMap(null);
      }
    }
  }
  myParcels = new Array();

  markerCount = 0;
  icons_used = new Array();
  myMarkers = new Array();
  myMarkersHTML = new Array();
  layer_legend_info = new Array();
  
  clear_layers();
  myLayers = new Array();
}
///////// Property Functions //////
function load_parcel_file(url){
  add_file_loading();
  var pRequest = new XMLHttpRequest();
  pRequest.onreadystatechange = function() {
    if (pRequest.readyState==4){
      if(pRequest.status==200){
	var xmlDoc = pRequest.responseXML;
	var parcels = xmlDoc.documentElement.getElementsByTagName("parcel");
	//console.log("parcel count " + parcels.length);
	myParcels = new Array();
	for (var i = 0; i < parcels.length; i++ ) {
	  //console.log("processing parcel #" + i);
	  createParcel(parcels[i]);
	}
	sub_file_loading();
      }
    }
  }
  pRequest.open("GET",url,true);
  pRequest.send();
  var legendItem = {};
  legendItem['name'] = "Private Land, Buffalo Friendly";
  legendItem['fill_color'] = "#00FF00";
  legendItem['fill_opacity'] = ".35";
  legendItem['line_width'] = "2";
  legendItem['line_color'] = "#FFFFFF";
  legendItem['line_opacity'] = "1.0";
  layer_legend_info.push(legendItem);
  
  legendItem = {};
  legendItem['name'] = "Private Land";
  legendItem['fill_color'] = "#FFF700";
  legendItem['fill_opacity'] = ".35";
  legendItem['line_width'] = "2";
  legendItem['line_color'] = "#FFFFFF";
  legendItem['line_opacity'] = "1.0";
  layer_legend_info.push(legendItem);
  
  legendItem = {};
  legendItem['name'] = "Private Land With Cows";
  legendItem['fill_color'] = "#FFF700";
  legendItem['fill_opacity'] = ".35";
  legendItem['line_width'] = "2";
  legendItem['line_color'] = "#FF0000";
  legendItem['line_opacity'] = "1.0";
  layer_legend_info.push(legendItem);
}

function createParcel(parcel){
  var coordStrings = parcel.getAttribute("coord_string").match(/[\d\.\-,]+/g);
  var points = new Array;
  var thisCoord;
  for(var c = 0; c < coordStrings.length; c++){
    thisCoord = coordStrings[c];
    if(thisCoord){
      var ll = thisCoord.match(/[\d\.\-]+/g);
      if(ll.length == 2){
        var point = new google.maps.LatLng(parseFloat(ll[1]),
				  parseFloat(ll[0]));
        points.push(point);
      }
    }
  }
  var fillColor;
  var outlineColor = "#FFFFFF";
  if(parcel.getAttribute("buffalo_friendly")){
    fillColor = "#00FF00";
  }else{
    fillColor = "#FFF700";
  }
  
  if(parcel.getAttribute("cows")){
    outlineColor = "#FF0000";
  }
  
  var poly =  new google.maps.Polygon({
	    paths: points,
	    strokeColor: outlineColor,
	    strokeOpacity: 0.8,
	    strokeWeight: 2,
	    fillColor: fillColor,
	    fillOpacity: 0.25
	    });
  if(parcel.getAttribute("center")){
    var ll = parcel.getAttribute("center").match(/[\d\.\-]+/g);
    if(ll.length == 2){
      var centerPoint = new google.maps.LatLng(parseFloat(ll[0]),
				  parseFloat(ll[1]));
      poly.position = centerPoint;
    }
  }
  if(!poly.position && points[0]){
    poly.position = points[0];
  }
  var infoHtml = parcel.getAttribute("owner_name");
  if(parcel.getAttribute("buffalo_friendly")){
    infoHtml += "<br /> Buffalo Friendly";
  }
  if(parcel.getAttribute("cows")){
    infoHtml += "<br />Cows";
  }
  if(parcel.getAttribute("notes")){
    infoHtml += "<br />" + parcel.getAttribute("notes");
  }
  if(conf['landmark_privledge']){
    infoHtml += '<br /><a target="input_frame" onclick="openFrame()" href="parcel.pl?action=edit&ParcelID=' + parcel.getAttribute("ParcelID") + '" >Edit</a>';
  }else{
    infoHtml += '<br /><a target="input_frame" onclick="openFrame()" href="parcel.pl?ParcelID=' + parcel.getAttribute("ParcelID") + '" >More Info</a>';
  }
  //console.log(infoHtml);
  google.maps.event.addListener(poly, "click", function() {
    infoWindow.setContent(infoHtml);
    infoWindow.open(map, poly);
  });
	  
  poly.setMap(map);
  myParcels.push(poly);
}
///////////  landmark functions ////////////
function gotoLandmark(){
  var ss = document.landmark_form.landmark_menu.value.match(/[\d\.\-]+/g);
  var point = new google.maps.LatLng(ss[0], ss[1]);
  map.panTo(point);
  //set_click_marker(point);
}

function load_landmark_file(url, iconurl){
  add_file_loading();
  var myRequest = new XMLHttpRequest();
  myRequest.onreadystatechange = function() {
    if (myRequest.readyState==4){
      if(myRequest.status==200){
	var xmlDoc = myRequest.responseXML;
	//clear the landmark menu
	document.landmark_form.landmark_menu.options.length = 0;
	document.landmark_form.landmark_menu.options[0] = new Option("Goto Landmark", "");
	// obtain the array of markers and loop through it
	var markers = xmlDoc.documentElement.getElementsByTagName("marker");
	for (var i = 0; i < markers.length; i++ ) {
	  // obtain the attribues of each marker
	  var mark = markers[i];
	  var point = new google.maps.LatLng(parseFloat(mark.getAttribute("latitude")),
				  parseFloat(mark.getAttribute("longitude")));
	  var html = mark.getAttribute("name");
	  
	  if(mark.getAttribute("image")){
	    html += "<br /><img src=" + mark.getAttribute("image") + " />";
	  }
	  if(mark.getAttribute("notes")){
	    html += "<br />Notes: " + mark.getAttribute("notes");
	  }
	  if(conf['landmark_privledge']){
	    html += '<br /><a target="input_frame" onclick="openFrame()" href="landmark.pl?action=edit&id=' +
	    mark.getAttribute("id") +
	    '">Edit</a>/<a target="input_frame"  onclick="openFrame()" href="landmark.pl?action=delete&id=' +
	    mark.getAttribute("id") + '">Delete</a>';
	  }
	  var marker_number;
	  // create the marker
	  var marker = createMarker(point, html, "landmark", iconurl, mark.getAttribute("name"), true);
	  myMarkers.push(marker);
	  marker_number =  (myMarkers.length - 1);
	  myMarkersHTML[marker_number] = html;
	  //add landmark to menu
	  document.landmark_form.landmark_menu.options[document.landmark_form.landmark_menu.options.length] = new Option(mark.getAttribute("name"), mark.getAttribute("latitude") + "," + mark.getAttribute("longitude"));
	}
      }
      sub_file_loading();
    }
  };
  myRequest.open("GET",url,true);
  myRequest.send();
}

///////        Marker functions   ////////
function createMarker(point2, html2, species, iconurl, label, set_location) {
  if(!iconurl){
    iconurl = getIconUrl(species);
  }
  var icon2 = new google.maps.MarkerImage(iconurl, null, null, new google.maps.Point(6, 20));
  var markerOptions = {
    icon: icon2,
    map: map,
    position: point2,
    title:label
  };

  var marker2 = new google.maps.Marker(markerOptions);

  google.maps.event.addListener(marker2, "click", function() {
      if(set_location){
	set_click_marker(point2);
      }
      infoWindow.setContent(html2);
      infoWindow.open(map, marker2);
    });
 
  return marker2;
}

function myRemoveMarker(marker){
    marker.setMap(null);
}

function openMarker(marker_number){
  infoWindow.setContent(myMarkersHTML[marker_number]);
  infoWindow.open(map, myMarkers[marker_number]);
}

function getIconUrl(species){
  if(icons_static[species]){
    return iconbase + icons_static[species];
  }else if(icons_used[species]){
    return iconbase + icons_used[species];	
  }else if(allocate_icon(species, icons_used)){
    return iconbase + icons_used[species];	
  }
}

function allocate_icon(species){
  var icon = icons_available.shift();
  if(icon){
    icons_used[species] = icon;
    return icon;
  }else{ 
    icons_used[species] =  icons_static["default"];
    return  icons_static["default"];
  }
}

/////////////////   menu functions  ///////
function selectAllSpecies(){
  for (var i = 0; i < document.menu_form.r_species.length; i++){ 
    document.menu_form.r_species[ i ].selected = true;
  }
}

function clearSpecies(){
  for (var i = 0; i < document.menu_form.r_species.length; i++){ 
    document.menu_form.r_species[ i ].selected = false;
  }
}

function choose_search_form(){
  var formname;
  for (var c = 0; c < document.menu_form.choose_form.length; c++){
    if( document.menu_form.choose_form[c].checked){
      formname = document.menu_form.choose_form[c].value;
    }
  }
  set_vis_by_class("range_form", "none");
  set_vis_by_class("series_form", "none");
  set_vis_by_class("my_sightings", "none");
  set_vis_by_class("name_form", "none");
  query_type = formname;
  set_vis_by_class(formname, "block");
}

function set_vis_by_class(fclass, vis){
  for (i=0;i<document.getElementsByTagName("li").length; i++) {
    if (document.getElementsByTagName("li").item(i).className == fclass){
      document.getElementsByTagName("li").item(i).style.display = vis;
    }
  }
}


function setDate(startdate, enddate){
  if(startdate.getYear() < 200){
    document.menu_form.r_startyear.value = startdate.getYear() + 1900;
  }else{
    document.menu_form.r_startyear.value = startdate.getYear();
  }
  document.menu_form.r_startmonth.value = (startdate.getMonth()+1);
  document.menu_form.r_startday.value = startdate.getDate();
  if(enddate.getYear() < 200){
    document.menu_form.r_endyear.value = enddate.getYear() + 1900;
  }else{
    document.menu_form.r_endyear.value = enddate.getYear();
  }
  document.menu_form.r_endmonth.value = (enddate.getMonth()+1);
  document.menu_form.r_endday.value = enddate.getDate();
}

////            legend functions ///
function update_legend(){
  var legend_html = "<table><tbody>";
  for(var species in icons_used){
    legend_html += "<tr><td><img src='" + getIconUrl(species) + "' /></td><td>" + species + "</td></tr>";
  }
  legend_html += "</table>";
  document.getElementById("legend").innerHTML = legend_html;
}

function update_layer_legend(){
  var legend_html = "<table><thead><tr><td></td><td></td><td></td></tr></thead><tbody>";
  for (var a = 0; a < layer_legend_info.length; a++) { 
   legend_html += "<tr><td><hr style='width: 30px;border:0px;height:" + layer_legend_info[a]["line_width"] + 
      "px;color:" + layer_legend_info[a]["line_color"] + ";background-color:" + layer_legend_info[a]["line_color"] + 
      ";opacity:" + layer_legend_info[a]["line_opacity"] + 
      "'></td><td><hr style='border:0px;width: 15px;height:15px;color: " + layer_legend_info[a]["fill_color"] + 
      ";background-color:" + layer_legend_info[a]["fill_color"] + 
      ";opacity:" + layer_legend_info[a]["fill_opacity"] + 
      "'></td><td>" + layer_legend_info[a]["name"] + "</td></tr>";
  }
  legend_html += "</tbody></table>";
  document.getElementById("layerLegend").innerHTML = legend_html;
}

/////////////    click functions ///
//this makes it so so double clicking doest mess things up
function checkclick ( point2 ) {
  if ( lastclick != point2 ) {
    lastclick = point2 ;
    set_click_marker( point2) ;
  }
}

function set_click_marker_string(ps){
  var ss = ps.match(/[\d\.\-]+/g);
  var point = new google.maps.LatLng(ss[0], ss[1]);
  set_click_marker(point);  
}

function set_click_marker( point) {
  if(input_frame.set_start_loc){
    if(!clickmarker){
	if(!startIcon){
	  startIcon = new google.maps.MarkerImage("http://www.google.com/mapfiles/dd-start.png", null, null, new google.maps.Point(6, 20));
	}
	var markerOptions = {
	  icon: startIcon,
	  map: map,
	  position: point,
	  draggable: true
	};
	clickmarker = new google.maps.Marker(markerOptions);
	 google.maps.event.addListener(clickmarker, "dragend", function(){
	     if(can_report_sightings) set_start_loc(clickmarker.getPosition().toUrlValue());}
	   );
	 set_start_loc(point.toUrlValue())
    }else if(!clickmarker_end && input_frame.set_end_loc(point.toUrlValue())){
      if(!endIcon){
	endIcon = new google.maps.MarkerImage("http://www.google.com/mapfiles/dd-end.png", null, null, new google.maps.Point(6, 20));
      }
      var markerOptions = {
	icon: endIcon,
        map: map,
	position: point,
	draggable: true
      };
      clickmarker_end =  new google.maps.Marker(markerOptions);
         google.maps.event.addListener(clickmarker_end, "dragend", function(){
	     if(can_report_sightings) set_end_loc(clickmarker_end.getPosition().toUrlValue());});
    }
  }
}

function set_end_loc(loc){
  if(input_frame.set_end_loc){
    input_frame.set_end_loc(loc);
  }
}

function set_start_loc(loc){
  if(input_frame.set_start_loc){
    input_frame.set_start_loc(loc);
  }
}

function clear_click_markers(){
  clear_click_marker();
  clear_click_marker_end();
}
function clear_click_marker(){
  if(clickmarker){
    clickmarker.setMap(null);
    clickmarker = null;
  }
}
function clear_click_marker_end(){
    if(clickmarker_end){
    clickmarker_end.setMap(null);
    clickmarker_end = null;
  }
}
/// message functions

function show_loading_message() {
  if(document.getElementById("loadingDiv").style.display != "block"){
    var hpos = (document.getElementById("mapdiv").offsetWidth/2) - 120;
    var vpos = (document.getElementById("mapdiv").offsetHeight/2) - 40;
    vpos = vpos.toFixed(0);
    hpos = hpos.toFixed(0);
    document.getElementById("loadingDiv").style.top = vpos + "px";
    document.getElementById("loadingDiv").style.left = hpos + "px";
    document.getElementById("loadingDiv").style.display = "block";
  }
}

function update_loading(){
  if(filesLoading > 0){
    show_loading_message();
  }
  var total_files = filesLoading + filesLoaded;
  var per = (filesLoaded/total_files) * 100;
  var percent = per.toFixed(0);
  document.getElementById("prog_filled_in").style.width = percent * 2 + "px";
  hide_loading_message();
}

function add_file_loading(){
  filesLoading++;
  update_loading();
}

function sub_file_loading(){
  filesLoading--;
  filesLoaded++;
  update_loading();
}

function hide_loading_message(){
  //hide loading message if everything is done loading
  if(filesLoading == 0){
    update_legend();
    update_layer_legend();
    document.getElementById("loadingDiv").style.display = "none";
  }
}

function showLayerReport() {
  popupWin = window.open('about:blank','layerwindow','width=800,height=300,resizable=1,menubar=0,toolbar=0,location=0,status=0,scrollbars=1');
  popupWin.document.write(layerHTML);
  popupWin.document.close();
}

function showReport() {
  popupWin = window.open('about:blank','reportwindow','width=800,height=300,resizable=1,menubar=0,toolbar=0,location=0,status=0,scrollbars=1');
  popupWin.document.write(reportHTML);
  popupWin.document.close();
}

//frame related functions
function openFrame() {
  document.getElementById("input_frame").style.display = "block";
  document.getElementById("mapdiv").style.bottom = "215px";
}

function closeFrame(){
  document.getElementById("input_frame").style.display = "none";
  document.getElementById("mapdiv").style.bottom = "15px";
}

function set_logged_in(){
  document.getElementById("login_link").style.display = "none";
  document.getElementById("logout_link").style.display = "block";
  conf["logged in"] = 1;
}

function set_logged_out(){
  document.getElementById("login_link").style.display = "block";
  document.getElementById("logout_link").style.display = "none";
  document.getElementById("report_sighting").style.display = "none";
  document.getElementById("admin_menu").style.display = "none";
  document.getElementById("password_link").style.display = "none";
  can_report_sightings = null;
  conf["logged in"] = 0;
  conf['admin'] = 0;
  conf['landmark_privledge'] = 0;
}

function set_admin(){
  document.getElementById("admin_menu").style.display = "block";
  conf['admin'] = 1;
  conf['landmark_privledge'] = 1;
}
function set_landmark_privledge(){
  document.getElementById("admin_menu").style.display = "block";
  conf['landmark_privledge'] = 1;
}
function set_password(){
  document.getElementById("password_link").style.display = "block";
}

function set_can_report_sightings(){
  can_report_sightings = 1;
  document.getElementById("report_sighting").style.display = "block";
}

function set_no_report_sightings(){
  can_report_sightings = 1;
  document.getElementById("report_sighting").style.display = "block";
}
