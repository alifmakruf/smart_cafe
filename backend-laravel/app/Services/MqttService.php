<?php

namespace App\Services;

use PhpMqtt\Client\MqttClient;
use PhpMqtt\Client\ConnectionSettings;

class MqttService
{
    protected $client;
    protected $host;
    protected $port;
    protected $clientId;

    public function __construct()
    {
        $this->host = env('MQTT_HOST', 'broker.hivemq.com');
        $this->port = env('MQTT_PORT', 1883);
        $this->clientId = env('MQTT_CLIENT_ID', 'laravel_' . uniqid());
    }

    protected function connect()
    {
        $this->client = new MqttClient($this->host, $this->port, $this->clientId);
        $connectionSettings = (new ConnectionSettings)
            ->setKeepAliveInterval(60)
            ->setConnectTimeout(3);
        
        $this->client->connect($connectionSettings, true);
        return $this->client;
    }

    public function publish($topic, $message, $qos = 0)
    {
        try {
            $client = $this->connect();
            $client->publish($topic, $message, $qos);
            $client->disconnect();
            return true;
        } catch (\Exception $e) {
            \Log::error("MQTT Publish Error: " . $e->getMessage());
            return false;
        }
    }

    public function subscribe($topic, $callback)
    {
        try {
            $client = $this->connect();
            $client->subscribe($topic, $callback, 0);
            $client->loop(true);
        } catch (\Exception $e) {
            \Log::error("MQTT Subscribe Error: " . $e->getMessage());
        }
    }
}