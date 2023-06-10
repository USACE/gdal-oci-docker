 FROM ubuntu:22.04
 
 # Set time zone
 ENV TZ=America/New_York
 RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

 ENV POSTGRES_VERSION 14
 ENV POSTGIS_VERSION 3
 ENV PROJ_VERSION 9.2.0
 ENV ORACLE_VERSION 19.8
 ENV GDAL_VERSION 3.7.0
 ARG NUMPY_VERSION=1.22.4
 
 
 RUN apt-get -y update && \
     apt-get install -y wget gnupg2 && \
     apt-get -y install \
     wget build-essential git cmake sqlite3 libsqlite3-dev libtiff-dev libcurl4-openssl-dev alien libaio1  \
     postgis postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION} pkg-config libpq-dev python3 python3-pip
 
 ENV INSTALL_DIR /opt/install
 RUN mkdir -p ${INSTALL_DIR}
 WORKDIR ${INSTALL_DIR}
 
 # Install Proj
 RUN git clone --depth 1 --branch ${PROJ_VERSION} https://github.com/OSGeo/PROJ.git
 WORKDIR ${INSTALL_DIR}/PROJ
 RUN mkdir build
 WORKDIR ${INSTALL_DIR}/PROJ/build
 RUN cmake .. && \
     cmake --build . && \
     cmake --build . --target install
 
 # Install Oracle client
 # https://help.ubuntu.com/community/Oracle%20Instant%20Client
 RUN mkdir -p ${INSTALL_DIR}/oracle
 WORKDIR ${INSTALL_DIR}/oracle
 RUN wget https://download.oracle.com/otn_software/linux/instantclient/19800/oracle-instantclient${ORACLE_VERSION}-basic-${ORACLE_VERSION}.0.0.0-1.x86_64.rpm && \
     wget https://download.oracle.com/otn_software/linux/instantclient/19800/oracle-instantclient${ORACLE_VERSION}-devel-${ORACLE_VERSION}.0.0.0-1.x86_64.rpm && \
     wget https://download.oracle.com/otn_software/linux/instantclient/19800/oracle-instantclient${ORACLE_VERSION}-sqlplus-${ORACLE_VERSION}.0.0.0-1.x86_64.rpm && \
     alien -i oracle-instantclient${ORACLE_VERSION}-basic-*.rpm && \
     alien -i oracle-instantclient${ORACLE_VERSION}-devel-*.rpm && \
     alien -i oracle-instantclient${ORACLE_VERSION}-sqlplus-*.rpm
ENV LD_LIBRARY_PATH=/usr/lib/oracle/${ORACLE_VERSION}/client64/lib/${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
ENV ORACLE_HOME=/usr/lib/oracle/${ORACLE_VERSION}/client64
RUN ln -s /usr/include/oracle/${ORACLE_VERSION}/client64 $ORACLE_HOME/include
ENV PATH=$PATH:$ORACLE_HOME/bin
RUN ldconfig

# Download & compile GDAL
WORKDIR ${INSTALL_DIR}
RUN wget https://github.com/OSGeo/gdal/releases/download/v${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz && \
    tar xvzf gdal-*.tar.gz
WORKDIR ${INSTALL_DIR}/gdal-${GDAL_VERSION}

RUN mkdir build &&\
    cd build &&\
    cmake .. &&\
    cmake --build . &&\
    cmake --build . --target install &&\
    ldconfig

# Update C env vars so compiler can find gdal
ENV CPLUS_INCLUDE_PATH=/usr/local/include
ENV C_INCLUDE_PATH=/usr/local/include

# Install python libs
WORKDIR ${INSTALL_DIR}
RUN echo "numpy==$NUMPY_VERSION\nGDAL==${GDAL_VERSION}\npsycopg2-binary==2.8.6\ncx-Oracle==8.0.1" > requirements.txt &&\
    pip3 install numpy==$NUMPY_VERSION && \
    pip3 install GDAL==${GDAL_VERSION} --global-option=build_ext --global-option="-I/usr/local/include" && \
    pip3 install -r requirements.txt

WORKDIR /root

# Uninstall unnecessary dependencies and delete install folder
RUN apt-get -y autoremove build-essential wget git alien && \
  rm -rf ${INSTALL_DIR}

