package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.json.JSONObject;
import java.util.Date;
import java.util.UUID;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import javax.crypto.spec.SecretKeySpec;
import javax.crypto.Mac;
import java.security.Key;
import java.util.Base64;

@RestController
public class HelloController {

    private static final String API_URL = "https://apim-devops-ta.azure-api.net/api/DevOps";
    private static final String API_KEY = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c";
    private static final String JWT_SECRET = "devops-ta-jwt";

    @GetMapping("/hello")
    public String hello() {
        // Generar el token JWT
        String token = generateToken();

        // Crear RestTemplate para hacer la solicitud
        RestTemplate restTemplate = new RestTemplate();

        // Configurar las cabeceras
        HttpHeaders headers = new HttpHeaders();
        headers.set("X-Parse-REST-API-Key", API_KEY);
        headers.set("X-JWT-KWY", token);
        headers.set("Content-Type", "application/json");

        // Crear el cuerpo de la solicitud en JSON
        JSONObject body = new JSONObject();
        body.put("message", "This is a test");
        body.put("to", "Juan Perez");
        body.put("from", "Rita Asturia");
        body.put("timeToLifeSec", "45");

        HttpEntity<String> entity = new HttpEntity<>(body.toString(), headers);

        // Hacer la solicitud POST
        String apiResponseMessage = "";
        try {
            ResponseEntity<String> response = restTemplate.exchange(API_URL, HttpMethod.POST, entity, String.class);

            // Parsear la respuesta JSON
            JSONObject jsonResponse = new JSONObject(response.getBody());
            apiResponseMessage = jsonResponse.getString("message");
        } catch (Exception e) {
            apiResponseMessage = "Error calling API: " + e.getMessage();
        }

        // Devolver el resultado en la respuesta
        return "Hello, World!<br>" + apiResponseMessage;
    }

    // Método para generar el token JWT
    private String generateToken() {
        // Derivar una clave segura de 256 bits (32 bytes) a partir del JWT_SECRET
        byte[] keyBytes = JWT_SECRET.getBytes();
        byte[] key256 = new byte[32];
        System.arraycopy(keyBytes, 0, key256, 0, Math.min(keyBytes.length, 32));

        Key signingKey = new SecretKeySpec(key256, SignatureAlgorithm.HS256.getJcaName());

        return Jwts.builder()
                .setSubject(UUID.randomUUID().toString())
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + 86400000)) // Token válido por 1 día
                .signWith(signingKey, SignatureAlgorithm.HS256)
                .compact();
    }
}
