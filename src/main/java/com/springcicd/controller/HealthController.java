package com.springcicd.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {

    @GetMapping("/")
    public String root() {
        return "ok";
    }

    @GetMapping("/ready")
    public String ready() {
        return "ready";
    }
}
