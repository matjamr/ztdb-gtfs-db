package it.edu.pk.ztdbbackend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.data.neo4j.repository.config.EnableNeo4jRepositories;
import org.springframework.data.projection.SpelAwareProxyProjectionFactory;

@SpringBootApplication
@EnableNeo4jRepositories
public class ZtdbBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(ZtdbBackendApplication.class, args);
    }

    @Bean
    public SpelAwareProxyProjectionFactory projectionFactory() {
        return new SpelAwareProxyProjectionFactory();
    }
}
