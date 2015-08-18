// ==UserScript==
// @name         Hide GHPRB "default" task
// @namespace    http://org.nonrational/
// @version      0.1
// @description  de-fault. de-fault. de-fault.
// @author       Alan Norton
// @match        https://github.com/**/pull/*
// @grant        none
// ==/UserScript==

$("span>strong:contains('default')").parent().parent().hide();
