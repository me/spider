google.load('visualization', '1', {'packages':['annotatedtimeline']});
google.setOnLoadCallback(function(e){
    drawChart($('#chart'));
});

var chartColumns = [];
var chartData = [];
var chart = null;
var chartSpinner;

function drawChart(div){
    if (!div) div = $('#chart');
    div = div.get(0);
    $C.remote('chart_data', {data: $C.currentAction, compare: chartColumns}, function(res){
        var data = new google.visualization.DataTable();
        data.addColumn('date', 'Date');
        for (var i=0; i<res.labels.length; i++){
            data.addColumn('number', res.labels[i]);
        }
        data.addRows(res.data.length);
        for (var i=0; i<res.data.length; i++){
            for (var j=0; j<res.data[i].length; j++){
                if (j==0){
                    res.data[i][j] = $.parseISODate(res.data[i][j]);
                }
                data.setValue(i, j, res.data[i][j]);
            }
        }
        chartData = data;
        if (!chart){
            chart = new google.visualization.AnnotatedTimeLine(div);
            google.visualization.events.addListener(chart, 'rangechange', function(e){
                console.log("Range: ");
                console.log(chart.getVisibleChartRange());
            });
        } 
        try{
            chart.draw(data); //, {'displayAnnotations': true});
        }
        catch(error){
            console.error(error);
        }
        
    });
}

$(document).ready(function(){
   $('#chart_add_column').change(function(){
       var select = $('#chart_add_column');
       var val = select.val();
       if (!val) return;
       var text = $("option[value='"+val+"']", select).text().substr(4);
       var li = $('<li />');
       li.text(text);
       $('<a href="#" class="remove">X</a>').appendTo(li).click(function(e){
           e.preventDefault();
           li.remove();
           removeChartColumn(val);
       });
       select.val(null);
       $('#chart-columns').append(li);
       addChartColumn(val);
       $('#chart-uniform').change(function(){
           var scaleType = $(this).is(':checked') ? 'allmaximized' : 'fixed';
           chart.draw(chartData, {allowRedraw: true, scaleType: scaleType});
       });
   });
});

function addChartColumn(column){
    chartColumns.push(column);
    drawChart();
}

function removeChartColumn(column){
    for (var i=0; i<chartColumns.length; i++){
        if (chartColumns[i] == column){
            chartColumns.splice(i, 1);
            break;
        } 
    }
    drawChart();
}

