import ipaddress


def classify_bind_scope(addr: str) -> str:
    """
    Classify LocalAddress as localhost / private / public / other
    """
    if not isinstance(addr, str) or addr.strip() == "":
        return "other"

    addr = addr.split("%")[0]  # remove IPv6 scope
    try:
        ip = ipaddress.ip_address(addr)
        if ip.is_loopback:
            return "localhost"
        if ip.is_private:
            return "private"
        return "public"
    except ValueError:
        return "other"
