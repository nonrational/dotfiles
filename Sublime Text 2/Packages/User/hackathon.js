function gen(s){
	var text = "";
    var possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    for( var i=0; i < 5; i++ )
        text += possible.charAt(Math.floor(Math.random() * possible.length));

    return text;
}
_gaq.push(['_trackEvent', '/', 'click_what', gen()]);
_gaq.push(['_trackEvent', '/what', 'hover_diversified', gen()]);
_gaq.push(['_trackEvent', '/what', 'hover_iras', gen()]);
_gaq.push(['_trackEvent', '/what', 'click_iras', gen()]);
_gaq.push(['_trackEvent', '/what/iras', 'click_why', gen()]);
_gaq.push(['_trackEvent', '/why', 'click_who', gen()]);
_gaq.push(['_trackEvent', '/who', 'hover_developer', gen()]);
_gaq.push(['_trackEvent', '/who', 'hover_biz', gen()]);
_gaq.push(['_trackEvent', '/who', 'hover_teacher', gen()]);
_gaq.push(['_trackEvent', '/who', 'click_tech', gen()]);
_gaq.push(['_trackEvent', '/who/tech', 'click_press1', gen()]);
_gaq.push(['_trackEvent', '/press', 'hover_ad1', gen()]);
_gaq.push(['_trackEvent', '/press', 'hover_ad2', gen()]);
_gaq.push(['_trackEvent', '/press', 'hover_ad3', gen()]);
_gaq.push(['_trackEvent', '/press', 'click_signup', gen()]);


/*_gaq.push(['_trackEvent', '/', 'click', gen()]);
_gaq.push(['_trackEvent', '/', 'click', gen()]);
_gaq.push(['_trackEvent', '/', 'click', gen()]);
_gaq.push(['_trackEvent', '/', 'click', gen()]);
_gaq.push(['_trackEvent', '/', 'click', gen()]);
_gaq.push(['_trackEvent', '/what', 'click', gen()]);
_gaq.push(['_trackEvent', '/what', 'click', gen()]);
_gaq.push(['_trackEvent', '/what', 'click', gen()]);
_gaq.push(['_trackEvent', '/what', 'click', gen()]);
_gaq.push(['_trackEvent', '/what', 'click', gen()]);
_gaq.push(['_trackEvent', '/what/iras', 'click', gen()]);
_gaq.push(['_trackEvent', '/what/iras', 'click', gen()]);
_gaq.push(['_trackEvent', '/what/iras', 'click', gen()]);
_gaq.push(['_trackEvent', '/what/iras', 'click', gen()]);
_gaq.push(['_trackEvent', '/what/iras', 'click', gen()]);
_gaq.push(['_trackEvent', '/why', 'click', gen()]);
_gaq.push(['_trackEvent', '/why', 'click', gen()]);
_gaq.push(['_trackEvent', '/why', 'click', gen()]);
_gaq.push(['_trackEvent', '/why', 'click', gen()]);
_gaq.push(['_trackEvent', '/why', 'click', gen()]);
_gaq.push(['_trackEvent', '/who', 'click', gen()]);
_gaq.push(['_trackEvent', '/who', 'click', gen()]);
_gaq.push(['_trackEvent', '/who', 'click', gen()]);
_gaq.push(['_trackEvent', '/who', 'click', gen()]);
_gaq.push(['_trackEvent', '/who', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/tech', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/tech', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/tech', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/tech', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/laywers', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/laywers', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/laywers', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/laywers', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/entrepreneurs', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/entrepreneurs', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/entrepreneurs', 'click', gen()]);
_gaq.push(['_trackEvent', '/who/entrepreneurs', 'click', gen()]);
_gaq.push(['_trackEvent', '/how', 'click', gen()]);
_gaq.push(['_trackEvent', '/how', 'click', gen()]);
_gaq.push(['_trackEvent', '/how', 'click', gen()]);
_gaq.push(['_trackEvent', '/how', 'click', gen()]);
_gaq.push(['_trackEvent', '/how', 'click', gen()]);
_gaq.push(['_trackEvent', '/pricing', 'click', gen()]);
_gaq.push(['_trackEvent', '/pricing', 'click', gen()]);
_gaq.push(['_trackEvent', '/pricing', 'click', gen()]);
_gaq.push(['_trackEvent', '/pricing', 'click', gen()]);
_gaq.push(['_trackEvent', '/press', 'click', gen()]);
_gaq.push(['_trackEvent', '/press', 'click', gen()]);
_gaq.push(['_trackEvent', '/press', 'click', gen()]);
_gaq.push(['_trackEvent', '/press', 'click', gen()]);
_gaq.push(['_trackEvent', '/about', 'click', gen()]);
_gaq.push(['_trackEvent', '/about', 'click', gen()]);
_gaq.push(['_trackEvent', '/about', 'click', gen()]);
_gaq.push(['_trackEvent', '/about', 'click', gen()]);*/
