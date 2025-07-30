# Automated Health Monitoring and Maintenance System
# This module provides comprehensive health monitoring, automated maintenance,
# and self-healing capabilities for the IPEX production environment.

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ipex-maintenance;
  
  # Health check script
  healthCheckScript = pkgs.writeShellScript "ipex-health-check" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Configuration
    LOG_FILE="/var/log/ipex-health.log"
    ALERT_EMAIL="${cfg.alerting.email}"
    SLACK_WEBHOOK="${cfg.alerting.slackWebhook}"
    
    # Logging function
    log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    }
    
    # Alert function
    alert() {
        local severity="$1"
        local message="$2"
        
        log "[$severity] $message"
        
        # Send email alert if configured
        if [[ -n "$ALERT_EMAIL" ]]; then
            echo "$message" | ${pkgs.mailutils}/bin/mail -s "IPEX Alert [$severity]" "$ALERT_EMAIL" || true
        fi
        
        # Send Slack alert if configured
        if [[ -n "$SLACK_WEBHOOK" ]]; then
            ${pkgs.curl}/bin/curl -X POST -H 'Content-type: application/json' \
                --data "{\"text\":\"🚨 IPEX Alert [$severity]: $message\"}" \
                "$SLACK_WEBHOOK" || true
        fi
    }
    
    # Check Intel GPU availability
    check_intel_gpu() {
        log "Checking Intel GPU availability..."
        
        if ! ${pkgs.intel-gpu-tools}/bin/intel_gpu_top -l 1 >/dev/null 2>&1; then
            alert "CRITICAL" "Intel GPU not accessible or not responding"
            return 1
        fi
        
        # Check GPU memory usage
        local gpu_memory_usage
        gpu_memory_usage=$(${pkgs.intel-gpu-tools}/bin/intel_gpu_top -l 1 | grep -o 'IMC.*%' | head -1 | grep -o '[0-9]*' || echo "0")
        
        if [[ $gpu_memory_usage -gt 90 ]]; then
            alert "WARNING" "Intel GPU memory usage high: $gpu_memory_usage%"
        fi
        
        log "Intel GPU check passed (Memory usage: $gpu_memory_usage%)"
        return 0
    }
    
    # Check IPEX services
    check_ipex_services() {
        log "Checking IPEX services..."
        
        # Check Ollama service
        if ! systemctl is-active --quiet ollama-ipex; then
            alert "CRITICAL" "Ollama-IPEX service is not running"
            log "Attempting to restart Ollama-IPEX service..."
            systemctl restart ollama-ipex || alert "CRITICAL" "Failed to restart Ollama-IPEX service"
        else
            # Test Ollama API responsiveness
            if ! ${pkgs.curl}/bin/curl -f -s --max-time 10 http://localhost:11434/api/tags >/dev/null; then
                alert "WARNING" "Ollama-IPEX API not responding, restarting service"
                systemctl restart ollama-ipex
            else
                log "Ollama-IPEX service check passed"
            fi
        fi
        
        # Check ComfyUI service
        if ! systemctl is-active --quiet comfyui-ipex; then
            alert "CRITICAL" "ComfyUI-IPEX service is not running"
            log "Attempting to restart ComfyUI-IPEX service..."
            systemctl restart comfyui-ipex || alert "CRITICAL" "Failed to restart ComfyUI-IPEX service"
        else
            # Test ComfyUI API responsiveness
            if ! ${pkgs.curl}/bin/curl -f -s --max-time 10 http://localhost:8188/system_stats >/dev/null; then
                alert "WARNING" "ComfyUI-IPEX API not responding, restarting service"
                systemctl restart comfyui-ipex
            else
                log "ComfyUI-IPEX service check passed"
            fi
        fi
    }
    
    # Check system resources
    check_system_resources() {
        log "Checking system resources..."
        
        # Check disk space
        local disk_usage
        disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
        
        if [[ $disk_usage -gt 85 ]]; then
            alert "WARNING" "Root disk usage high: $disk_usage%"
            
            # Trigger cleanup if usage is critical
            if [[ $disk_usage -gt 95 ]]; then
                alert "CRITICAL" "Root disk usage critical: $disk_usage%, triggering cleanup"
                systemctl start ipex-cleanup
            fi
        fi
        
        # Check memory usage
        local memory_usage
        memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
        
        if [[ $memory_usage -gt 90 ]]; then
            alert "WARNING" "Memory usage high: $memory_usage%"
        fi
        
        # Check load average
        local load_avg
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        local cpu_count
        cpu_count=$(nproc)
        
        if (( $(echo "$load_avg > $cpu_count * 2" | ${pkgs.bc}/bin/bc -l) )); then
            alert "WARNING" "High system load: $load_avg (CPUs: $cpu_count)"
        fi
        
        log "System resources check passed (Disk: $disk_usage%, Memory: $memory_usage%, Load: $load_avg)"
    }
    
    # Check network connectivity
    check_network() {
        log "Checking network connectivity..."
        
        # Check internet connectivity
        if ! ${pkgs.curl}/bin/curl -f -s --max-time 5 http://www.google.com >/dev/null; then
            alert "WARNING" "Internet connectivity issues detected"
        fi
        
        # Check internal service connectivity
        if ! ${pkgs.curl}/bin/curl -f -s --max-time 5 http://localhost:9090/api/v1/query?query=up >/dev/null; then
            alert "WARNING" "Prometheus not responding"
        fi
        
        log "Network connectivity check passed"
    }
    
    # Performance benchmark
    run_performance_check() {
        log "Running performance benchmark..."
        
        # Run quick IPEX benchmark
        local benchmark_result
        benchmark_result=$(timeout 60 ${pkgs.ipex-benchmarks}/bin/ipex-benchmark --quick --tensor-only 2>&1 || echo "FAILED")
        
        if [[ "$benchmark_result" == *"FAILED"* ]]; then
            alert "WARNING" "IPEX performance benchmark failed"
        else
            log "Performance benchmark completed successfully"
        fi
    }
    
    # Main health check routine
    main() {
        log "Starting IPEX health check..."
        
        local exit_code=0
        
        check_intel_gpu || exit_code=1
        check_ipex_services || exit_code=1
        check_system_resources || exit_code=1
        check_network || exit_code=1
        
        # Run performance check periodically (not every run)
        if [[ $(date +%M) == "00" ]]; then  # Every hour
            run_performance_check || exit_code=1
        fi
        
        if [[ $exit_code -eq 0 ]]; then
            log "All health checks passed ✅"
        else
            log "Some health checks failed ❌"
        fi
        
        return $exit_code
    }
    
    main "$@"
  '';
  
  # Cleanup script
  cleanupScript = pkgs.writeShellScript "ipex-cleanup" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE="/var/log/ipex-cleanup.log"
    
    log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    }
    
    log "Starting IPEX cleanup..."
    
    # Clean old logs
    log "Cleaning old log files..."
    find /var/log -name "*.log" -type f -mtime +30 -delete || true
    find /var/log -name "*.log.*" -type f -mtime +7 -delete || true
    
    # Clean temporary files
    log "Cleaning temporary files..."
    find /tmp -type f -mtime +1 -delete || true
    find /var/tmp -type f -mtime +7 -delete || true
    
    # Clean old model cache if enabled
    if [[ -d "/var/cache/comfyui" ]]; then
        log "Cleaning old ComfyUI cache..."
        find /var/cache/comfyui -type f -mtime +7 -delete || true
    fi
    
    # Clean old Nix generations
    log "Cleaning old Nix generations..."
    nix-collect-garbage -d || true
    
    # Clean Docker if present
    if command -v docker >/dev/null 2>&1; then
        log "Cleaning Docker resources..."
        docker system prune -f || true
    fi
    
    # Clean package cache
    log "Cleaning package cache..."
    nix-store --gc || true
    
    log "Cleanup completed"
  '';
  
  # Update script
  updateScript = pkgs.writeShellScript "ipex-update" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE="/var/log/ipex-update.log"
    
    log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    }
    
    log "Starting IPEX system update..."
    
    # Pre-update backup
    log "Creating pre-update backup..."
    mkdir -p /var/backups/ipex
    
    # Backup configurations
    rsync -av /etc/nixos/ "/var/backups/ipex/nixos-$(date +%Y%m%d-%H%M%S)/" || true
    
    # Backup service data
    systemctl stop ollama-ipex comfyui-ipex || true
    rsync -av /var/lib/ollama/ "/var/backups/ipex/ollama-$(date +%Y%m%d-%H%M%S)/" || true
    rsync -av /var/lib/comfyui/ "/var/backups/ipex/comfyui-$(date +%Y%m%d-%H%M%S)/" || true
    
    # Update system
    log "Updating NixOS system..."
    nixos-rebuild switch --upgrade || {
        log "System update failed, restoring services..."
        systemctl start ollama-ipex comfyui-ipex
        exit 1
    }
    
    # Restart services
    log "Restarting IPEX services..."
    systemctl start ollama-ipex comfyui-ipex
    
    # Wait for services to be ready
    sleep 30
    
    # Validate services
    log "Validating services after update..."
    if ! ${pkgs.curl}/bin/curl -f -s --max-time 10 http://localhost:11434/api/tags >/dev/null; then
        log "Ollama validation failed after update"
        exit 1
    fi
    
    if ! ${pkgs.curl}/bin/curl -f -s --max-time 10 http://localhost:8188/system_stats >/dev/null; then
        log "ComfyUI validation failed after update"
        exit 1
    fi
    
    log "System update completed successfully"
  '';

in
{
  options.services.ipex-maintenance = {
    enable = mkEnableOption "IPEX automated maintenance and monitoring";
    
    healthCheck = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated health checks";
      };
      
      interval = mkOption {
        type = types.str;
        default = "*/5 * * * *";  # Every 5 minutes
        description = "Health check interval (cron format)";
      };
    };
    
    cleanup = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated cleanup";
      };
      
      schedule = mkOption {
        type = types.str;
        default = "0 2 * * *";  # Daily at 2 AM
        description = "Cleanup schedule (cron format)";
      };
    };
    
    updates = {
      enable = mkOption {
        type = types.bool;
        default = false;  # Disabled by default for production
        description = "Enable automated updates";
      };
      
      schedule = mkOption {
        type = types.str;
        default = "0 4 * * 0";  # Weekly on Sunday at 4 AM
        description = "Update schedule (cron format)";
      };
    };
    
    alerting = {
      email = mkOption {
        type = types.str;
        default = "";
        description = "Email address for alerts";
      };
      
      slackWebhook = mkOption {
        type = types.str;
        default = "";
        description = "Slack webhook URL for alerts";
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Health monitoring service
    systemd.services.ipex-health-check = mkIf cfg.healthCheck.enable {
      description = "IPEX Health Check";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${healthCheckScript}";
      };
    };
    
    systemd.timers.ipex-health-check = mkIf cfg.healthCheck.enable {
      description = "IPEX Health Check Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.healthCheck.interval;
        Persistent = true;
        RandomizedDelaySec = "60s";
      };
    };
    
    # Cleanup service
    systemd.services.ipex-cleanup = mkIf cfg.cleanup.enable {
      description = "IPEX System Cleanup";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${cleanupScript}";
        IOSchedulingClass = 3;  # Idle priority
        CPUSchedulingPolicy = 3;  # Batch scheduling
      };
    };
    
    systemd.timers.ipex-cleanup = mkIf cfg.cleanup.enable {
      description = "IPEX Cleanup Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.cleanup.schedule;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
    
    # Update service
    systemd.services.ipex-update = mkIf cfg.updates.enable {
      description = "IPEX System Update";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${updateScript}";
      };
    };
    
    systemd.timers.ipex-update = mkIf cfg.updates.enable {
      description = "IPEX Update Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.updates.schedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
    
    # Log directories
    systemd.tmpfiles.rules = [
      "d /var/log/ipex 0755 root root -"
      "d /var/backups/ipex 0755 root root -"
    ];
    
    # Required packages
    environment.systemPackages = with pkgs; [
      healthCheckScript
      cleanupScript
      updateScript
      intel-gpu-tools
      curl
      mailutils
      bc
    ];
  };
}
