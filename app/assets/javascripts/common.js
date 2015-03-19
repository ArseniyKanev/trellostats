$(document).ready(function() {
  function checkSaveAll() {
    flag = true;
    $(".upload").each(function (){
      if ($(this).is(':visible')) {
        $("#upload_all").show();
        flag = false;
      }
    });
    if (flag === true) { $("#upload_all").hide(); }
  }
  function checkExclamation() {
    var valid = false;
    var equality = false;
    var updatable = false;
    $(".card_name").each(function (){
      if ($(this).css("background").indexOf("255, 112, 112") > -1) {
        valid = true;
        var id = $(this).data("id");
        $("#popup" + id).attr('title',  $(this).data("valid")[1]);
      }
      if ($(this).css("background").indexOf("255, 255, 51") > -1) { equality = true; }
      if ($(this).css("background").indexOf("128, 230, 128") > -1) { updatable = true; }
    });
    if (updatable) {
      $(".exclamation").show();
      $(".exclamation").css('color', '#80e680');
    }
    if (equality) {
      $(".exclamation").show();
      $(".exclamation").css('color', '#FFFF33');
    }
    if (valid) {
      $(".exclamation").show();
      $(".exclamation").css('color', '#FF7070');
    } 
    if (!valid && !equality && !updatable) {
      $(".exclamation").hide();
    }
  }
  $(".card_name" ).each(function (){
    var id = $(this).data("id");
    if ($(this).data("valid")[0] === false) { $(this).css('background', '#FF7070'); }
    if ($(this).data("equality") === false) { $(this).css('background', '#FFFF33'); }
    if ($(this).data("updatable") === true) {
      $(this).css('background', '#80e680');
      $("#upload" + id).show();
    }
    $("#upload" + id).click(function() {
      var answer = confirm("Обновить карточку?");
      if (answer) {
        $("#upload" + id).hide();
        $("#upload_spinner" + id).show();
        $.ajax({
          url: '/lists/update_card/',
          type: 'GET',
          data: { card_id: id },
          success: function(result) {
            $("#upload_spinner" + id).hide();
            $("#card_name" + id).css('background', 'white');
            $("#estimated" + id).text(result.estimated);
            $("#spent" + id).text(result.spent);
            $("#offhour" + id).text(result.offhour);
            $("#bugfix" + id).text(result.bugfix);
            $("#total_estimated").text(result.total_estimated);
            $("#total_work").text(result.total_work);
            $("#total_bugfix").text(result.total_bugfix);
            $("#spent" + id).prop('title',  result.factor_time_spent);
            $("#offhour" + id).prop('title',  result.factor_time_offhour);
            $("#bugfix" + id).prop('title',  result.factor_time_bugfix);
            checkExclamation();
            checkSaveAll();
          }
        });
      }
    })
    $("#refresh" + id).click(function() {
      $("#refresh" + id).hide();
      $("#refresh_spinner" + id).show();
      $.ajax({
        url: '/lists/refresh_card/',
        type: 'GET',
        data: { card_id: id },
        success: function(result) {
          if (result.valid[0] === false) {
            $("#card_name" + id).css('background', '#FF7070');
            $("#popup" + id).attr("title", result.valid[1]);
          }
          if (result.equality === false) { $("#card_name" + id).css('background', '#FFFF33'); }
          if (result.updatable === true) {
            $("#card_name" + id).css('background', '#80e680');
            $("#upload" + id).show();
          }
          if (result.valid[0] === true && result.equality === true && result.updatable === false) { $("#card_name" + id).css('background', 'white'); }
          $("#refresh_spinner" + id).hide();
          $("#refresh" + id).show();
          $("#estimated" + id).text(result.estimated);
          $("#spent" + id).text(result.spent);
          $("#offhour" + id).text(result.offhour);
          $("#bugfix" + id).text(result.bugfix);
          $("#total_estimated").text(result.total_estimated);
          $("#total_work").text(result.total_work);
          $("#total_bugfix").text(result.total_bugfix);
          $("#spent" + id).prop('title',  result.factor_time_spent);
          $("#offhour" + id).prop('title',  result.factor_time_offhour);
          $("#bugfix" + id).prop('title',  result.factor_time_bugfix);
          checkExclamation();
          checkSaveAll();
        }
      });
    })
  });
  $("#upload_all").click(function() {
    var answer = confirm("Обновить все карточки");
    if (answer) {
      $(".card_name").each(function() {
        var id = $(this).data("id");
        if ($("#upload" + id).is(":visible")) {
          $("#upload" + id).hide();
          $("#upload_spinner" + id).show();
          $.ajax({
            url: '/lists/update_card/',
            type: 'GET',
            data: { card_id: id },
            success: function(result) {
              $("#upload_all").hide();
              $("#upload_spinner" + id).hide();
              $("#card_name" + id).css('background', 'white');
              $("#estimated" + id).text(result.estimated);
              $("#spent" + id).text(result.spent);
              $("#offhour" + id).text(result.offhour);
              $("#bugfix" + id).text(result.bugfix);
              $("#total_estimated").text(result.total_estimated);
              $("#total_work").text(result.total_work);
              $("#total_bugfix").text(result.total_bugfix);
              $("#spent" + id).prop('title',  result.factor_time_spent);
              $("#offhour" + id).prop('title',  result.factor_time_offhour);
              $("#bugfix" + id).prop('title',  result.factor_time_bugfix);
              checkExclamation();
            }
          });
        }
      });
    }
  });
  checkExclamation();
  checkSaveAll();
});
