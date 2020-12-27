$(document).ready(function() {
	$('#table_comuni').DataTable( {
		"autoWidth": true,
		"ajax": "dati/comuni.json",
		"columns": [
		{ "data": "MAPPA" },
		{ "data": "COMUNE" },
		{ "data": "ABITANTI" },
		{ "data": "SUPERFICIE (km²)" },
		{ "data": "PROV" },
		],
		columnDefs: [{
			targets: 0,
			render: function ( data, type, row, meta ) {
				if(type === 'display'){
					values = data.split("_");
					idistat = values[0];
					abitanti = parseFloat(values[1]);
					if (parseFloat(values[1]) <= 5000) { 
						data = '<a target="_new" href="mappa.html?id=' + idistat + '">vedi</a>';
					} else {
						data = ''
					}
				}
				return data;
			}
		}]
	});
});