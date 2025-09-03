package com.springcicd.controller;

import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestMapping;

@RestController
public class Controller {
    
    @RequestMapping("/")
    public String index() {
        return "Hello World\n";
    }
    
}
