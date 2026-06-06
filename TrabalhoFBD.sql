--------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS promocao CASCADE;
DROP TABLE IF EXISTS Review CASCADE;
DROP TABLE IF EXISTS itens_pedidos CASCADE;
DROP TABLE IF EXISTS Pedidos CASCADE;
DROP TABLE IF EXISTS Armazena CASCADE;
DROP TABLE IF EXISTS Biblioteca CASCADE;
DROP TABLE IF EXISTS Desbloqueia CASCADE;
DROP TABLE IF EXISTS Conquista CASCADE;
DROP TABLE IF EXISTS Dlc CASCADE;
DROP TABLE IF EXISTS Jogo CASCADE;
DROP TABLE IF EXISTS Produto CASCADE;
DROP TABLE IF EXISTS Desenvolvedora CASCADE;
DROP TABLE IF EXISTS Usuario CASCADE;
--------------------------------------------------------------------------------------------------

CREATE TABLE Usuario(
	id_user SERIAL PRIMARY KEY,
	nome varchar(100) NOT NULL,
	senha varchar(100) NOT NULL,
	data_nascimento DATE,
	email varchar(100) UNIQUE NOT NULL,
	nickname varchar(100) UNIQUE NOT NULL
);

CREATE TABLE Desenvolvedora(
	id_desenvolvedora SERIAL PRIMARY KEY,
	comissao_plat varchar(100),
	razao_social varchar(100) NOT NULL,
	cnpj varchar(18) UNIQUE NOT NULL
);

CREATE TABLE Produto(
	id_produto SERIAL PRIMARY KEY,
	id_desenvolvedora INT NOT NULL,
	FOREIGN KEY (id_desenvolvedora) REFERENCES Desenvolvedora(id_desenvolvedora),
	data_lancamento DATE NOT NULL,
	Nome varchar(100) NOT NULL,
	tags varchar(100),
	descricao varchar(200),
	tipo_produto varchar(100),
	preco_base DECIMAL(10,2) NOT NULL,
	status varchar(50)
);

CREATE TABLE Jogo (
	id_produto INT PRIMARY KEY,
	classificacao_indicativa INT,
	engine varchar(50),
	has_multiplayer boolean,
	requisitos_sistema varchar(200),
	FOREIGN KEY (id_produto) REFERENCES Produto(id_produto) ON DELETE CASCADE
);

CREATE TABLE Dlc(
	id_produto INT PRIMARY KEY,
	tipo_conteudo varchar(100),
	id_jogo_pai INT NOT NULL,            -- FK para saber de qual jogo é essa DLC
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto) ON DELETE CASCADE,
    FOREIGN KEY (id_jogo_pai) REFERENCES Jogo(id_produto)
);

CREATE TABLE Conquista(
	id_jogo INT, -- FK
	id_conquista SERIAL,
	titulo varchar(100) NOT NULL,
	descricao TEXT,
	PRIMARY KEY (id_jogo, id_conquista),
	-- A FK aponta diretamente para a PK de Jogo (que no fundo é id_produto)
	FOREIGN KEY (id_jogo) REFERENCES Jogo(id_produto) ON DELETE CASCADE
);

CREATE TABLE Desbloqueia(
	id_user INT,
    id_jogo INT,
    id_conquista INT,
    PRIMARY KEY (id_user, id_jogo, id_conquista),
    FOREIGN KEY (id_user) REFERENCES Usuario(id_user) ON DELETE CASCADE,
    -- Como a PK de conquista é composta, a FK aqui também precisa ser dupla:
    FOREIGN KEY (id_jogo, id_conquista) REFERENCES Conquista(id_jogo, id_conquista) ON DELETE CASCADE
);

CREATE TABLE Biblioteca (
	id_biblioteca SERIAL PRIMARY KEY,
	qntd_jogos INT DEFAULT 0,
	data_atualizacao DATE,
	id_user INT UNIQUE NOT NULL,
	FOREIGN KEY(id_user) REFERENCES Usuario(id_user) ON DELETE CASCADE                                                                 
);

CREATE TABLE Armazena(
	id_biblioteca INT,
    id_produto INT,
    PRIMARY KEY (id_biblioteca, id_produto), 
    tempo_jogado TIME DEFAULT '00:00:00',
    ultima_sessao TIMESTAMP,         
    data_aqs DATE,
    status_progresso VARCHAR(100),
    FOREIGN KEY (id_biblioteca) REFERENCES Biblioteca(id_biblioteca) ON DELETE CASCADE,
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto)
);
CREATE TABLE Pedidos(
	id_pedido SERIAL PRIMARY KEY,
	data_compra DATE NOT NULL,
	status boolean,
	valor_pedido DECIMAL(10,2),
	id_user INT NOT NULL,
	FOREIGN KEY (id_user) REFERENCES Usuario(id_user)
);

CREATE TABLE itens_pedidos(
    id_pedido INT,
    id_produto INT,
    quantidade INT NOT NULL DEFAULT 1,
    preco_momento DECIMAL(10,2) NOT NULL,
    preco_original DECIMAL(10,2) NOT NULL,
    status_pedido VARCHAR(20),
    PRIMARY KEY (id_pedido, id_produto),
    FOREIGN KEY (id_pedido) REFERENCES Pedidos(id_pedido) ON DELETE CASCADE,
    FOREIGN KEY (id_produto) REFERENCES Produto(id_produto)
);

CREATE TABLE Review(
	id_review SERIAL PRIMARY KEY,
	data_postagem DATE NOT NULL,
	nota INT NOT NULL CHECK (nota BETWEEN 1 AND 5),
	cometario TEXT,
	id_user INT NOT NULL,
	FOREIGN KEY (id_user) REFERENCES Usuario(id_user),
	id_produto INT NOT NULL,
	FOREIGN KEY(id_produto) REFERENCES Produto(id_produto)
);

CREATE TABLE promocao(
	id_promocao SERIAL PRIMARY KEY,
	id_produto INT NOT NULL,
	FOREIGN KEY (id_produto) REFERENCES Produto(id_produto) ON DELETE CASCADE, 
	data_fim DATE NOT NULL,
	data_inicio DATE NOT NULL,
	percentual_desconto DECIMAL(5,2) NOT NULL
);